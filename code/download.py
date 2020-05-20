from torchvision.models import resnet34

# Triggers download of the model (~100mb). Be sure this matches
# the model used for dev. For Production, we load our own trained
# model so there is no need to download this.
# Saves somewhere like /root/.cache/torch/checkpoints/
# https://pytorch.org/docs/stable/torchvision/models.html
resnet34(pretrained=True, progress=False)
