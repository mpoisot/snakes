FROM python:3.8-slim-buster as base

RUN apt-get update && \
  apt-get install -y --no-install-recommends python3-dev gcc && \
  rm -rf /var/lib/apt/lists/*

# Use virtualenv. Create into the given folder. Then set PATH so future commands use it.
# https://pythonspeed.com/articles/multi-stage-docker-python/
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Non-cuda (CPU only) pytorch libs save more than a GIG vs a simple `pip install torch torchvision`.
# Even so, python libs still contribute >700 MB.
# Get exact pytorch PIP cmd from this page, using settings: stable, linux, pip, python, CUDA=none.
# https://pytorch.org/get-started/locally/
COPY requirements.txt .
RUN pip install -r requirements.txt
# RUN pip install --quiet --no-cache-dir \
#   starlette uvicorn python-multipart aiohttp \
#   torch==1.5.0+cpu torchvision==0.6.0+cpu --find-links https://download.pytorch.org/whl/torch_stable.html \
#   fastai~=1.0


##########################################

FROM python:3.8-slim-buster as prod

# Use virtualenv
COPY --from=base /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

WORKDIR /app
COPY server.py server.py
COPY training/trained_model.pkl training/trained_model.pkl

EXPOSE ${PORT}

# Run the image as a non-root user to ensure it will work on Heroku
RUN adduser --disabled-password --gecos '' someuser
USER someuser

# Start the server. Shell CMD so process sees all ENV vars
CMD uvicorn server:app --host 0.0.0.0 --port $PORT

##########################################

FROM base as dev

# Use virtualenv
COPY --from=base /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Download pretrained models
COPY download.py download.py
RUN python download.py

RUN apt-get update && \
  apt-get install -y --no-install-recommends git procps && \
  rm -rf /var/lib/apt/lists/*

RUN pip install --quiet --no-cache-dir jupyter notebook jupyter_contrib_nbextensions pylint black

WORKDIR /app

EXPOSE ${PORT}

# Start the server. Shell CMD so process sees all ENV vars
# Expects code to be mounted over /app
CMD uvicorn server:app --host 0.0.0.0 --port $PORT  --reload
