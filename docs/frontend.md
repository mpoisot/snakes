## Deploy JS Frontend to Heroku

- install herok CLI. https://devcenter.heroku.com/articles/heroku-cli
- heroku create
- heroku config:add BACKEND_URL=https://snakes-api.herokuapp.com
  - NO final /
- git push heroku

## Deploy JS Frontend to Vercel

- formerly Zeit / Now.sh
- install [Vercel CLI](https://vercel.com/download)
- vercel --build-env BACKEND_URL=https://snakes-api.herokuapp.com

