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

It turns out VScode has a great [docker extension](https://code.visualstudio.com/docs/remote/containers). There's an ok GUI for starting and stopping containers, but the command line is better for that. But what's amazing is VSCode can connect to container and run from *inside* there. That means intellisense happily understands those linux-only libraries that wouldn't install in MacOS land. I can run Jupyter notebooks and interactive python files and everything works.

## Docker

Here's the [Dockerfile]([Dockerfile](../Dockerfile)). Lots of lessons learned along the way.

Alpine linux is attractively small as the starting image, weighing in at only 5 MB. But it uses a different C compiler that breaks many things, including Pytorch and VScode. So use a "slim" version of Debian instead. Better yet, use a slim debian image with python goodies already installed. Weight: ~200 MB for python:3.8-slim-buster.

To leverage docker's caching to speed up builds, and more importantly to slim down the production image size, I created a [multi-stage build](https://docs.docker.com/develop/develop-images/multistage-build/) Dockerfile.

### Base Stage

The first stage isn't used directly, it's only used as a base for the later stages. The goal is to get python libraries installed and compiled, and then only use the minimal set of files for the production stage. Python libs are installed using [virtualenv](https://virtualenv.pypa.io/en/latest/) so that they all live under one folder instead of spread around the filesystem.

Initially I installed `torch` and `torchvision` pips. But the resulting image was 3 GB! The backend server will be a regular, cheap compute unit on Heroku that lacks GPU support. After some investigation I found out how to get non-CUDA (non-GPU) versions of those libs. This shaved off about 1 GB. Even so, the resulting virtualenv folder weighs in at about 700 MB.

### Prod Stage

The prod stage will be used in production and needs to be as small as possible. Here we copy just the virtualenv files over from the base stage. We don't need gcc or python-dev at this point. This shaves off about 200 MB.

Next we copy the server script and the 90 MB trained model. Heroku runs Docker containers as non-root user, so they recommend testing to make sure that works.

### Dev Stage

The dev stage builds off the base stage and adds nice stuff like git, jupyter notebook support and other stuff that VSCode will need for extensions to work.

The entire project folder gets mounted over /app so it's easy to work with files inside or outside the container and everything just works.

Fast.ai has a nice feature where if you create a model with pretrained parameters like resnet34, it will fetch that 100 MB file for you and then cache it. Normally that works great, but with docker it won't stick around next time I tinker with the Dockerfile. So I created a tiny script [download.py](../code/download.py) that triggers that download, and call it in the Dockerfile.

## Compose

- compose to easily launch containers. I don't use for multi containers simultaneously, I really use it as a way to not have to type out docker run --lotsofopts
- DataLoader with lots of images will crash with default settings. Either use just one worker, or increase the /dev/shm limit when creating the container. `run XXX --shm-size=2g”
- Docker desktop for Mac has additional resource limits by default. I bumped up the memory and cpus. Requires a container restart.

## Jupyter Notebooks vs Regular Python in VScode

The VScode [Python Extension](https://marketplace.visualstudio.com/items?itemName=ms-python.python) is fully featured. It can display Jupyter notebook files, although some things like `doc()` don't work at all.

More interestingly, for regular .py files it can display python output similar to a notebook when a section of code uses the magic comment `# %%`. Big whoop, they reinvented Jupyter. Why bother?

After reading an article on the subject I realized that code diffing can be a nightmare with Jupyter files, but with .py files it works great. Moreover, the VScode python extension comes with actions to convert from .py to .ipynb and back.

VScode command palette (CMD+P):

```
> Python: Export Current Python File as Jupyter Notebook
> Python: Export Current Python File and Output as Jupyter Notebook
> Python: Convert to Python Script
```

Converting modifies some of the nicer looking imports into an uglier (but presumably equally functional) form. Aside from that it all works great for me so far.

Another benefit to workting in .py files is VScode's intellisense, code formatting, etc. all work as expected. They either don't work or don't work well in the .ipynb format.

So my current method is to work on .py files directly, and then export to .ipynb when I want to work in Jupyter. I treat the .py file as the single source of truth, and the .ipynb can be trashed or overwritten as needed.

### Hosted GPU Server vs Local

- Gradient / Paperspace
- git and download/upload
- BS
- speed

## Server.py

- export/load is new way. way nicer. no need to worry about the exact ImageBunch definition.
- Python Starlette on top of uvicorn server. Can upload file or url to perform prediction, send results as JSON. Minimal html page.

## Deploy Python Backend to Heroku

- Zeit / now.sh / Vercel doesn't support docker anymore.
- Heroku supports docker. Initial image was 3GB! I moved to a multistage build to separate building pip libs from the compiled libs. Cpu only version of pytorch saves about 1 GB. Separate dev goodies out to separate image. Image is stil gigantic (1GB). Fortunately heroku doesn't have a hard size limit.
- docker history helped me see what added what.
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
