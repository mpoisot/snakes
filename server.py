from starlette.applications import Starlette
from starlette.responses import JSONResponse, HTMLResponse, RedirectResponse
from fastai.vision import (
    open_image,
    load_learner,
)
from starlette.middleware import Middleware
from starlette.middleware.cors import CORSMiddleware
import torch
from pathlib import Path
from io import BytesIO
import sys
import uvicorn
import aiohttp
import asyncio
import os


learner = load_learner(Path("/app"), Path("/app/training/trained_model.pkl"))

# TODO: less open CORS def. We'd need to pass the frontend server's domain name via ENV var.
middleware = [Middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"])]
app = Starlette(middleware=middleware, debug=True)


@app.route("/upload", methods=["POST"])
async def upload(request):
    data = await request.form()
    bytes = await (data["file"].read())
    return predict_image_from_bytes(bytes)


@app.route("/classify-url", methods=["POST"])
async def classify_url(request):
    data = await request.form()
    url = data["url"]
    print(f"url = {url} ")
    bytes = await get_bytes(url)
    return predict_image_from_bytes(bytes)


async def get_bytes(url):
    async with aiohttp.ClientSession() as session:
        async with session.get(url) as response:
            return await response.read()


def predict_image_from_bytes(bytes):
    img = open_image(BytesIO(bytes))
    _pred_class, _pred_idx, outputs = learner.predict(img)

    return JSONResponse(
        {
            "predictions": sorted(
                zip(learner.data.classes, map(float, outputs)),
                key=lambda p: p[1],
                reverse=True,
            )
        }
    )


@app.route("/")
def form(request):
    return HTMLResponse(
        """
        <form action="/upload" method="post" enctype="multipart/form-data">
            Select image to upload:
            <input type="file" name="file">
            <input type="submit" value="Upload Image">
        </form>
        Or submit a URL:
        <form action="/classify-url" method="get">
            <input type="url" name="url">
            <input type="submit" value="Fetch and analyze image">
        </form>
    """
    )


if __name__ == "__main__":
    if "serve" in sys.argv:
        port = int(os.environ.get("PORT"))
        if not port:
            print(
                "Error: PORT environment variable must be set. The server will listen on this port."
            )
            exit(-1)
        uvicorn.run(app, host="0.0.0.0", port=port)
