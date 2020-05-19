# Coral vs King Snake Image Classifier

This project is a demonstration of what I learned from the first few lessons of the [2019 Fast.ai MOOC](https://course.fast.ai/). The goal is to train an image classifier that can distinguish between deadly coral snakes ([Micrurus tener](https://en.wikipedia.org/wiki/Micrurus_tener)) and harmless king snakes ([scarlet kingsnake](https://en.wikipedia.org/wiki/Scarlet_kingsnake)). It's a demo project so don't take the results too seriously.

The project is composed of 3 major parts: model training environment, backend API server and frontend webserver.

## Training The Model

The model is created using Jupyter notebooks that can run on remote servers with powerful GPUs. The initial model is a convolutional neural network using Resnet34 architechture and pretrained parameters from ImageNet. I trained the model using several hundred images harvested using various search engines. I used techniques from the Fast.ai course to train using a succession of learning rates. The resulting model is 95% accurate according to the validation set composed of 85 images.

Read more [here](docs/training.md)

## Python Backend Server

The backend API is a python-based web server that wraps the trained, exported model created by the training environment. This server provides an API that accepts an image or url, and returns prediction data as JSON. The server runs in a Docker container so it can run on development desktop machines or deploy to remote hosts such as Heroku.

Read more  [here](docs/backend.md)

## Javascript Frontend Server

The frontend server uses the [Next.js](https://nextjs.org/) framework to serve React-powered web pages. The 2 server frontend/backend architechture is arguably overkill for this demo, but is a realistic set up for how a production website might integrate a python-powered model into their existing javascript-based platform.

Read more details [here](docs/frontend.md)

## Demo

[View the live demo](https://snakes.poisot.com/). The frontend is hosted with [Vercel](https://vercel.com), the backend is hosted on [Heroku](https://www.heroku.com/). The Heroku server is using the free tier. The downside is the server is put to sleep after a period of inactivity, so the initial initial upload will have a noticeable 15 second delay before the progress bar moves beyond 0%.

