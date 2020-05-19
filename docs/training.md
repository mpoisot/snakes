# Training The Model

## Images

I harvested 233 images of coral snakes, and 193 images of king snakes using Google, Bing and Flickr image search engines with help from the [FastClass](https://github.com/cwerner/fastclass) utility program. Along the way I added Flickr support to the FastClass and PR'ed my addition back to cwerner's project.

FastClass fits rectangular images into a square, and fills the gap with white. I felt that the start white padding was hurting my results. So I added the ability to not pad the images to fit in a square, and instead keet them rectangular. This way I can let fast.ai's transformations do their thing picking random crops and filling in gaps with reflections of the image instead of solid colors. If I really needed to I could crop square images manually to keep the main subject in frame. I did not PR that code back to the main repo because of merge conflicts.

## Training

Look at snakes.py (or \_snakes.ipynb which is derived from snakes.py) to see how I created the model. I created a resnet34 pretrained model, split the images into 80% training, 20% validation, applied default image transformations, and trained with `fit_one_cycle` for 4 epochs. XXXRESULTS.

Next I used unfroze the model, used the learning rate finder and a few iterations of trial and error to settle on a max learning rate of `slice(1e-4,3e-4)` (keeping the recommended 3e-4 rate for the later layers). I ran another 4 epochs using this new learning rate rate on the unfrozen model. XXXRESULTS.

- results
- screenshots

<img alt='training stage 1' src='training/train1.png' height='150' />
