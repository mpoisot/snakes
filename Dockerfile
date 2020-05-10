FROM python:3.8-slim-buster

RUN apt-get update && \
  apt-get install -y --no-install-recommends python3-dev gcc && \
  rm -rf /var/lib/apt/lists/*

# Install pytorch and fastai
# RUN pip install torch_nightly -f https://download.pytorch.org/whl/nightly/cpu/torch_nightly.html
RUN pip install torch~=1.5 fastai~=1.0

# Install starlette and uvicorn
RUN pip install starlette uvicorn python-multipart aiohttp

WORKDIR /app
COPY cougar.py cougar.py
COPY export.pkl export.pkl

# Run it once to trigger resnet download
RUN python cougar.py

EXPOSE 8008

# Start the server
CMD ["python", "cougar.py", "serve"]
