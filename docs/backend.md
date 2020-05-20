# Backend Python API Server

The raw model is made available online by a barebones webserver. The backend wraps the trained model exported by the [training environment](training.md) with a Python-based web server that accepts either an uploaded image file or URL, and returns the prediction data as JSON.

The server's homepage can be used on it's own, but the intention is for it to be a API consumed by a friendlier [frontend](frontend.md) web service.

## Cougar or Not

The inspiration for this part of the project came from Fast.ai 2019 lesson 2. The instructor mentions a project by former student Simon Willison called [Cougar or Not](https://github.com/simonw/cougar-or-not), where he wrapped the trained model in a Python webserver. The server ran inside a Docker container, and could easily be deployed to Zeit's Now.sh platform. Cool! It should only take a day to get my model working, right?

It turns out lots of things changed and broke in the intervening year or so. But I felt that getting a trained model out of Jupyter and onto the web was a worthy goal. I will want to do this with any useful future models, so why not get it working with my silly snakes model?

## Get It Working on MacOS

First things first. I needed to get Cougar or Not working on my local dev machine. I cloned the repo, installed the pips... and discovered Fast.ai won't install properly on MacOS, at least not out of the box.

No worries, that's what [Docker](https://www.docker.com/) is for. I hope. I've been meaning to take a deep dive into Docker for years so this felt like a worthy deep dive.

"Docker for Desktop" is a super easy one click install on MacOS. But it took a solid week of reading and fiddling to wrap my head around how Docker works, how to build and optimize images, how Compose works and if I should use it, and how to get my nice devlelopment environment all figured out. And then several more days to actually export a working server to a cloud provider.

It turns out VScode has a great [docker extension](https://code.visualstudio.com/docs/remote/containers). There's an ok GUI for starting and stopping containers, but the command line is better for that. But what's amazing is VSCode can connect to container and run from *inside* there. That means intellisense happily finds those linux-only libraries that wouldn't install in MacOS land. I can run Jupyter notebooks and interactive python files and everything works.



## Dockerfile

Here's the [Dockerfile]([Dockerfile](../Dockerfile)). Lots of lessons learned along the way.

Alpine linux is attractively small as the starting image, weighin in at only 5 MB. But it uses a different C compiler that breaks many things, including Pytorch and VScode. So use a "slim" version of Debian instead. Better yet, use a slim debian image with python goodies already installed.

To leverage docker's caching to speed up builds, and more importantly to slim down the production image size I created a [multi-stage build](https://docs.docker.com/develop/develop-images/multistage-build/) Dockerfile.

### Base stage

The first stage isn't used directly, it's only used as a branch point for the later stages. The goal is to get python libraries installed and compiled, and then only use the output for the production stage. Python libs are installed using [virtualenv](https://virtualenv.pypa.io/en/latest/)

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
