# Backend Server

The raw model is made available online by a minimal Python-based webserver. This server is fully functional on it's own but the intention is for it to be a API consumed by a friendlier frontend web service. To that end, Next, a javascript-based front end wraps the API provided by the python webserver 

I wrapped the trained model with a Python-based web server that accepts either an uploaded image or URL that points to an image, and returns the prediction data as JSON.

## Web Wrapper for Trained Model

- other guy's starlette app as starting point
- export/load is new way
- 87 mb file
- Python Starlette on top of uvicorn server. Can upload file or url to perform prediction, send results as JSON. Minimal html page.

## Docker for Python

- fastai won't install on mac
- docker works great
- multistage dockerfile for local dev vs slimmed down production image
- compose to easily launch containers. I don't use for multi containers simultaneously, I really use it as a way to not have to type out docker run --lotsofopts
- VScode docker extension is great. Connect to running container so the libs within the container are used for VScode intellisense and Jupyter notebooks work (but things widgets don't work, like doc()). Vs-code specific compose file to tweak settings.
- Zeit / now.sh / Vercel doesn't support docker anymore.
- Heroku supports docker. Initial image was 3GB! I moved to a multistage build to separate building pip libs from the compiled libs. Cpu only version of pytorch saves about 1 GB. Separate dev goodies out to separate image. Image is stil gigantic (1GB). Fortunately heroku doesn't have a hard size limit.
- docker history helped me see what added what.
- Apline linux sounds nice but doesn't work with pytorch and vscode.
- DataLoader with lots of images will crash with default settings. Either use just one worker, or increase the /dev/shm limit when creating the container. `run XXX --shm-size=2g”
- Docker desktop for Mac has additional resource limits by default. I bumped up the memory and cpus. Requires a container restart.

## VSCode

- motivation
- docker & compose
- gradient vs local
- extensions
- jupyter vs #%% in .py files. Convert.
- doc() doesn't work


## Deploy Python Backend to Heroku

- Heroku’s `container:push` doesn’t understand compose, nor can I find a way to tell it which build target within the Dockerfile to use, so it pushes all the images combined!
- The solution appears to be to build the image myself using compose, then push the image to heroku “manually”. The correct naming scheme must be followed. https://devcenter.heroku.com/articles/container-registry-and-runtime#pushing-an-existing-image
- One time setup
  heroku create
  heroku auth:token | docker login --username=\_ --password-stdin registry.heroku.com
- every time steps
  compose build web
  docker tag snakes_web:latest registry.heroku.com/glacial-anchorage-17811/web
  docker push registry.heroku.com/glacial-anchorage-17811/web
  heroku container:release web
