# Backend Python API Server

The raw model is made available online by a barebones webserver. The backend wraps the trained model exported by the [training environment](training.md) with a Python-based web server that accepts either an uploaded image file or URL, and returns the prediction data as JSON.

The server's homepage can be used on it's own, but the intention is for it to be a API consumed by a friendlier [frontend](frontend.md) web service.

## Cougar or Not

The inspiration for this part of the project came from Fast.ai 2019 lesson 2. The instructor mentions a project by former student Simon Willison called [Cougar or Not](https://github.com/simonw/cougar-or-not), where he wrapped the trained model in a Python webserver. The server ran inside a Docker container, and could easily be deployed to Zeit's Now.sh platform. Cool! It should only take a day to get my model working, right?

It turns out lots of things changed and broke in the intervening year or so. But I felt that getting a trained model out of Jupyter and onto the web was a worthy goal. I will want to do this with any useful future models, so why not get it working with my silly snakes model?

## MacOS

First things first. I needed to get Cougar or Not working on my local dev machine. I cloned the repo, installed the pips... and discovered Fast.ai won't install properly on MacOS, at least not out of the box.

No worries, that's what [Docker](https://www.docker.com/) is for. I hope. I've been meaning to take a deep dive into Docker for years so this felt like a worthy deep dive.

"Docker for Desktop" is a super easy one click install on MacOS. But it took a solid week of reading and fiddling to wrap my head around how Docker works, how to build and optimize images, how Compose works and if I should use it, and how to get my nice devlelopment environment all figured out. And then several more days to actually export a working server to a cloud provider.

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

## Compose > Docker Run

After typing `docker run --blah --blah --blah` a few times I started thinking of how to achieve a better DX. My first thought was make a simple shell script. Then I stumbled upon [Docker Compose](https://docs.docker.com/compose/). Compose does a lot of neat stuff like launching several containers that interact with each other over a private network, but I'm not using any of that. I only run one container at a time, either `dev` or `prod`. I'm just using Compose as a glorified config for running containers.

### Shm_size

I ran into annoying crashes trying to load images for training. The reason has to do with something deep within [ImageDataBunch](https://docs.fast.ai/vision.data.html#ImageDataBunch) (I think [DeviceDataLoader](https://docs.fast.ai/basic_data.html#DeviceDataLoader)), where several workers fetch and transform images in parallel. In my Docker environment this quickly lead to a shortage of shared memory and crash. The solution was to boost it via the `--shm_size` option to `docker run` or Compose. I chose 2 GB and never had issues after that. Another solution I read somewhere is to change the number of workers to 0, but I never tried that.

### Volume Mount

For development it's really convenient to just mount the whole project folder into the container. However there can be performance issues keeping things in sync. I'm using the `:delegated` flag which provides the [most performant](https://docs.docker.com/docker-for-mac/osxfs-caching/) version of shared volumes on MacOS, but with some risk of weirdness. So far I haven't had any issues. 

### Docker Desktop Default Resource Limits

Docker Desktop for Mac has system [resource limits](https://docs.docker.com/docker-for-mac/#resources) that seem pretty conservative. I maxed out the resources: CPUs (8), memory (16 GB), swap (4 GB) and disk image size (64 GB).

## VS Code & Docker

It turns out VScode has an excellent official [docker extension](https://code.visualstudio.com/docs/remote/containers). There's an ok GUI for starting and stopping containers, but really the command line is better for that. 

What's amazing is VSCode can connect to container and run from *inside* there. That means intellisense happily finds those linux-only python libraries that wouldn't install in MacOS land. I can run Jupyter notebooks and interactive python files and everything works.

### devcontainer.json

VScode uses [devcontainer.json](../.devcontainer/devcontainer.json) to configure the instance of VScode that runs *inside* the container. Here are a few key fields I modified and the [docs](https://code.visualstudio.com/docs/remote/containers#_devcontainerjson-reference).

- `service` & `runServices` This is the service name in the Compose file to build and run the default container for this project. Since I only run one of the 2 services at any given time, `runServices` needs to be set or it defaults to starting all services. Initially for prod and dev use the same server port which meant bind failures trying to start both.
- `workspaceFolder` before I set this VS Code would ask every time where to find the workspace files. Set it to the same folder where the project is mounted (or where your code is COPY'd).
- `extensions` these VScode extensions are automatically installed inside the container. Otherwise you have to manually install them from the extensions every time the container changes.
- `python.pythonPath` set to the locatation of the python executable. I had to set this after switching to virtualenv.

### .devcontainer/docker-compose.yml

By default, VScode will use your existing docker-compose.yml and [extend](https://docs.docker.com/compose/extends/) it with a second compose file. This let's you override or add a few configs when connecting VScode to the container, yet not have to keep 2 files in sync for common settings. This was definitely a source of confusion for me.

I ended up disabling everything in this file except for `command`, which runs an infinite loop instead of the python web server. This is better for the dev container, because if the web server crashes on startup the container will quit if that's the main command.

### Jupyter Notebooks vs Regular Python

The VScode [Python Extension](https://marketplace.visualstudio.com/items?itemName=ms-python.python) has a ton of features, including the ability to run Jupyter notebook files. However some things like `doc()` are broken, and some widgets like progress bars don't display correctly. From what I read the official Jupyter server works better.

Even more interesting, for regular .py files VScode can display [Jupyter-like code cells](https://code.visualstudio.com/docs/python/jupyter-support-py#_jupyter-code-cells) by using the magic comment `# %%`. Big whoop, they reinvented Jupyter. Who cares?

After reading [an article](https://towardsdatascience.com/jupyter-notebooks-in-the-ide-visual-studio-code-versus-pycharm-5e72218eb3e8) on the subject I realized that code diffing could be a noisy pain with Jupyter files, but with .py files it works cleanly as expected. Intellisense, code formatting, debugging, etc. all work. For me working with .py files feels better. It's low-risk to try because the VScode python extension comes with actions to [convert from .py to .ipynb and back](https://code.visualstudio.com/docs/python/jupyter-support-py#_convert-jupyter-notebooks-to-python-code-file).

So my current method is to work on .py files directly, and then export to .ipynb when I want to play with things in Jupyter (such as on a remote GPU powered server). I treat the .py file as the single source of truth, and the .ipynb can be trashed or overwritten as needed.

### Hosted GPU Server vs Local

I've been using [Gradient by Paperspace](https://gradient.paperspace.com/) as a GPU powered Jupyter host. They have a free plan that works just fine for this kind of project. The Nvidia P5000 16 GB GPUs complete training 10-20x faster than my laptop. 

#### Code Sync

After I get training code working I export to .ipynb and commit to github. On the Gradient host I `git pull` the latest code and run that. When I'm done I download the exported trained model via the web interface.

I had issues getting `git push` to work from the Gradient host, but I'm sure its possible. I just haven't needed it yet since it was easy to download that one model file.

## Server&#46;py

[Server.py](../code/server.py) was adapted from [Cougar or Not](https://github.com/simonw/cougar-or-not). Mostly I just deleted a bunch of obsolete code for setting up the model and ImageDataBunch. [Export](https://docs.fast.ai/basic_train.html#Learner.export) encodes all of that critical setup information so that `load_learner()` is an easy and safe one-liner. Thanks fast.ai!

The server uses the [Starlette](https://www.starlette.io/) framework connected to a uvicorn server. I considered adding gunicorn as suggested by the [uvicorn docs](https://www.uvicorn.org/#running-with-gunicorn), but I wasn't sure how much memory each worker needs and setting too many workers could lead to some crashes.

The server exposes 3 endpoints:

- Upload a image file
- Upload a url that points to an image
- A very basic webpage with a form to upload an image.

## Deploy To Hosting Service

### Zeit

After I got everything working on my local box I looked into deploying the Docker image to Zeit.co as the Cougar or Not author suggested. It turns out (A) Zeit is now [Vercel](https://vercel.com/), and (B) they no longer accept docker images. Doh!

Instead they've moved on to fancy [serverless functions](https://vercel.com/docs/v2/serverless-functions/introduction). They do allow python, and will [install whatever libs](https://vercel.com/docs/runtimes#official-runtimes/python/python-dependencies) you need from requirements.txt. Ok great. **Nope**, there is a hard 50 MB limit on function size, which apparently includes all libs. My serverless build was clocking in close to a **1 GB**. 

### Heroku

Fortunately [Heroku](https://www.heroku.com/) accepts Docker images even on the free tier, and there aren't [hard limits on image size](https://devcenter.heroku.com/articles/container-registry-and-runtime#known-issues-and-limitations) (slug size). The deploy worked! Finally. 

However, that initial deploy image weighed in at **3 GB**. Yowsa! It took forever to upload, I'm bet it slows down wake times (free tier servers are put to sleep), and who knows when Heroku will decide to impose a hard limit.

Unfortunately their docker support is half baked. There are [nice commands](https://devcenter.heroku.com/articles/container-registry-and-runtime#getting-started) to push your images, but it doesn't understand compose or multi-stage builds so the image includes all the extra stuff in the `snakes-dev` image. Fortunately it's easy to build the image myself using `compose build prod` so that only my `snakes-prod` image gets built. Then tag, push and release to Heroku to deploy it (be sure to use their [special naming scheme](https://devcenter.heroku.com/articles/container-registry-and-runtime#pushing-an-existing-image)). That shaved a few hundred MB off. A good start.

I learned how to use [docker history](https://docs.docker.com/engine/reference/commandline/history/) to see how much each step increases the final image. I figured out a bunch of ways to optimize the production image, which are detailed in the [Docker section](#Docker). I squeezed the production image down to 1 GB.
