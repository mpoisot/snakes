FROM python:3.8-slim-buster as base

RUN apt-get update && \
  apt-get install -y --no-install-recommends python3-dev gcc && \
  rm -rf /var/lib/apt/lists/*

# Use virtualenv. Create into the given folder. Then set PATH so future commands use it.
# https://pythonspeed.com/articles/multi-stage-docker-python/
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

COPY requirements.txt .
RUN pip install -r requirements.txt

##########################################

FROM python:3.8-slim-buster as prod

# Use virtualenv
COPY --from=base /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

WORKDIR /app
COPY code/server.py code/server.py
COPY training/trained_model.pkl training/trained_model.pkl

EXPOSE ${PORT}

# Run the image as a non-root user to ensure it will work on Heroku
RUN adduser --disabled-password --gecos '' someuser
USER someuser

# Start the server. Shell CMD so process sees all ENV vars
CMD cd code && uvicorn server:app --host 0.0.0.0 --port $PORT

##########################################

FROM base as dev

# Use virtualenv
COPY --from=base /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Download pretrained models
COPY code/download.py code/download.py
RUN python code/download.py

RUN apt-get update && \
  apt-get install -y --no-install-recommends git procps && \
  rm -rf /var/lib/apt/lists/*

RUN pip install --quiet --no-cache-dir jupyter notebook jupyter_contrib_nbextensions pylint black

WORKDIR /app

EXPOSE ${PORT}

# Start the server. Shell CMD so process sees all ENV vars
# Expects code to be mounted over /app
CMD cd code && uvicorn server:app --host 0.0.0.0 --port $PORT  --reload
