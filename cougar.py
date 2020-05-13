from starlette.applications import Starlette
from starlette.responses import JSONResponse, HTMLResponse, RedirectResponse
from fastai.vision import (
    # ImageDataBunch,
    # ConvLearner,
    open_image,
    # get_transforms,
    # models,
    load_learner,
)
import torch
from pathlib import Path
from io import BytesIO
import sys
import uvicorn
import aiohttp
import asyncio
import os


async def get_bytes(url):
    async with aiohttp.ClientSession() as session:
        async with session.get(url) as response:
            return await response.read()


app = Starlette()

# cat_images_path = Path("/tmp")
# cat_fnames = [
#     "/{}_1.jpg".format(c)
#     for c in [
#         "Bobcat",
#         "Mountain-Lion",
#         "Domestic-Cat",
#         "Western-Bobcat",
#         "Canada-Lynx",
#         "North-American-Mountain-Lion",
#         "Eastern-Bobcat",
#         "Central-American-Ocelot",
#         "Ocelot",
#         "Jaguar",
#     ]
# ]
# cat_data = ImageDataBunch.from_name_re(
#     cat_images_path,
#     cat_fnames,
#     r"/([^/]+)_\d+.jpg$",
#     ds_tfms=get_transforms(),
#     size=224,
# )

# cat_learner = ConvLearner(cat_data, models.resnet34)
# cat_learner.model.load_state_dict(
#     torch.load("usa-inaturalist-cats.pth", map_location="cpu")
# )

learner = load_learner(Path("/app"), Path("/app/export.pkl"))


@app.route("/upload", methods=["POST"])
async def upload(request):
    data = await request.form()
    bytes = await (data["file"].read())
    return predict_image_from_bytes(bytes)


@app.route("/classify-url", methods=["GET"])
async def classify_url(request):
    bytes = await get_bytes(request.query_params["url"])
    return predict_image_from_bytes(bytes)


def predict_image_from_bytes(bytes):
    img = open_image(BytesIO(bytes))
    pred_class, pred_idx, outputs = learner.predict(img)

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


@app.route("/form")
def redirect_to_homepage(request):
    return RedirectResponse("/")


if __name__ == "__main__":
    if "serve" in sys.argv:
        port = os.environ.get("PORT")
        if not port:
            print(
                "Error: PORT environment variable must be set. The server will listen on this port."
            )
            exit(-1)
        uvicorn.run(app, host="0.0.0.0", port=port)
