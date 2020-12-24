# Use python image based off alpine
FROM python:3.9.1-alpine3.12

# Set the working directory
WORKDIR /sensorsqc

# Copy the app
COPY . /sensorsqc

# Install the dependencies
RUN pip3 install -r requirements.txt

# Expose the required port
EXPOSE 5000

# Create non-root user to run the app
RUN adduser --disabled-password --home /sensorsqc app && chown -R app /sensorsqc
USER app

# Run
ENTRYPOINT [ "python3" ]
CMD [ "sensorsqc.py" ]