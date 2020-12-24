# ------------------------------------------------------------
#  Imports
# ------------------------------------------------------------
import logging, traceback, re, time
from statistics import mean, stdev
from collections import defaultdict, OrderedDict
from flask import Flask, request, render_template, g

# ------------------------------------------------------------
#  Classes & Functions
# ------------------------------------------------------------
# Get the value of the extra args passed during POST
# TODO: Validations
class GetExtraArgsValue:
    def __init__(self, arg):
        self.arg = arg

    # Let's return false as default value
    def __str__(self):
        if request.form.get(self.arg):
            return request.form.get(self.arg).lower()
        else:
            return 'false'

# Work with the reference temp & humidity
# TODO: Validations
class References:
    def __init__(self, name, temp, humidity):
        self.name = name
        self.temp = temp
        self.humidity = humidity

    @classmethod
    def from_string(cls, line):
        name, temp, humidity = line.split(' ', 3)
        if not name == 'reference':
            raise Exception('Reference line (temperature & humidity) is not valid. Please ensure the format is correct. More details on the console logs.')

        return cls(name, temp, humidity)

# Let's check the file is valid
def isFileValid(file):
    if not file.filename == '':
        if file.content_type == 'text/plain' or file.content_type == 'application/octet-stream':
            return True, None
        else:
            err_msg = 'Content type ' + file.content_type + ' is not supported'
            return False, err_msg
    else:
        err_msg = 'Please select a log file to evaluate'
        return False, err_msg

# Check if this will be a new group or a reading
def isHeader(txt):
    # Using regex, we'll determine if the line contains a date timestamp or a header
    # This assumes the timestamp will be formatted consistently
    # Example Timestamps:
    #     2007-04-05T22:00
    #     2017-01-05T22:00
    regexTimestampPattern = '[0-9]{4}-(0[1-9]|1[0-2])-(0[1-9]|[1-2][0-9]|3[0-1])T(2[0-3]|[01][0-9]):[0-5][0-9]'

    if bool(re.match(regexTimestampPattern, txt)):
        return False
    else:
        return True

# TODO: Convert this to a class?
def isSensorTypeAndNameSupported(type,name):
    # Types and naming convention we support
    allowed_sensor_types_and_name = [
        {"type": "thermometer", "name": "temp-"},
        {"type": "humidity", "name": "hum-"}
    ]

    if any(d['type'].lower() == type for d in allowed_sensor_types_and_name):
        # Check if it matches the naming convention from the dictionary
        get_sensor_name_pattern = [d['name'].lower() for d in allowed_sensor_types_and_name if type in d['type']][0]

        if not name.startswith(get_sensor_name_pattern):
            err_msg = 'The sensor name ' + name + ' does not conform to the pattern ' + get_sensor_name_pattern + '. Skipping readings!'
            return False, err_msg
        else:
            return True, None
    else:
        err_msg = 'The sensor type ' + type + ' is not supported. Skipping readings!'
        return False, err_msg

# TODO: Convert this to a class?
def getQCResult(sensor,readings,reference):
    # TODO: While we validated the sensor name before getting here,
    #       See if there's a better way to know the type, maybe add the type to our dictionary?

    # Thermometer
    if sensor.startswith('temp-'):
        temp_mean = float(mean(readings)) # Mean
        temp_std_dev = float(stdev(readings)) # Standard Deviation
        temp_mean_dev = abs(float(reference.temp) - temp_mean) # Mean temperature deviation (absolute value)

        result = 'precise' # Default result
        if temp_mean_dev <= 0.5:
            if temp_std_dev < 3:
                result = 'ultra precise'
            if temp_std_dev >= 3 and temp_std_dev < 5:
                result = 'very precise'
    # Humidity
    elif sensor.startswith('hum-'):
        # Let's get the allowed humidity deviation, 1% within the reference value
        hum_allowed_deviation = 0.01 * float(reference.humidity)

        if stdev(readings) < hum_allowed_deviation:
            result = 'keep'
        else:
            result = 'discard'
    else:
        result = 'currently not supported due to no type logic'

    return result

# ------------------------------------------------------------
#  Flask
# ------------------------------------------------------------
app = Flask(__name__)
app.config['JSON_SORT_KEYS'] = False # This is to mimic the sample output, by default flask sorts the JSON out alphabetically
app.config['MAX_CONTENT_LENGTH'] = 100 * 1024 * 1024 # Limit the size that can be uploaded. Not really tested.

@app.route('/')
def upload():
    return render_template("index.html")

@app.before_request
def before_request():
    # Used to get metrics
    g.request_start_time = time.time()
    g.request_time = lambda: "%.6fs" % (time.time() - g.request_start_time)

@app.route('/qc', methods = ['POST'])
def process():
    if request.method == 'POST':
        # Get the POST values
        f = request.files['file']

        # Let's check if the file is valid first
        if isFileValid(f)[0]:
            # Let's create a dictionary to store our output data
            dict_final_output = OrderedDict()

            # Load the whole file into memory
            # TODO: This will probably not scale with extremely large log files.
            #       Need to find a way to stream the data, or change the log captures
            #       to a limited scope - like maybe 1 log file/sensor/day
            data = f.read().decode('utf8').strip().splitlines()

            # Variables
            dict_data = defaultdict(list)
            isSensorSupported = False

            # Loop through each line, skip the first (reference) line
            for line in data[1:]:
                # If line is empty, skip it
                if re.match(r'^\s*$', line):
                    continue

                # Split up the line so we can parse the objects
                sLine = line.split()

                if isHeader(sLine[0]):
                    current_sensor_type = sLine[0].lower()
                    current_sensor_name = sLine[1].lower()

                    # Check if the type is supported
                    val_sensor_name_and_type = isSensorTypeAndNameSupported(current_sensor_type,current_sensor_name)

                    if val_sensor_name_and_type[0]:
                        isSensorSupported = True
                    else:
                        # Unsupported type, let's log it
                        isSensorSupported = False
                        err_msg = val_sensor_name_and_type[1]
                        logging.warning(err_msg)

                        # If we have displayerror to true, let's add it to our final results
                        if str(GetExtraArgsValue("displayerror")).lower() == 'true':
                            dict_final_output[current_sensor_name] = err_msg
                else:
                    if isSensorSupported:
                        # TODO: Validation
                        dict_data[current_sensor_name].append(float(sLine[1]))
                    else:
                        logging.warning("Reading skipped...")

            # Let's process the final results
            for sensor in dict_data:
                dict_final_output[sensor] = getQCResult(sensor,dict_data[sensor],References.from_string(data[0]))

            # Display how long it took to process
            print("!!!!!!!!! Processed file " + f.filename + " in " + g.request_time() + " !!!!!!!!!!!!")

            # Add how long it took on to the dictionary, this can easily be enabled by using curl or postman. Default is false.
            if str(GetExtraArgsValue("displaytime")).lower() == 'true':
                dict_final_output['time'] = g.request_time()

            # Display the results back as JSON
            return dict_final_output
        else:
            msg = isFileValid(f)[1]
            logging.error(msg)
            return render_template("index.html", message = "Error! " + str(msg)), 400

if __name__ == '__main__':
    app.run(host='0.0.0.0',debug = True)