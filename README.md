# ResourceSync Validator

ResourceSync Validator is a Sitemap/ResourceSync validation tool. It can parse a Sitemap and provide a human-friendly version of the sitemap along with validation information.

![screen shot 2014-04-29 at 22 35 05](https://cloud.githubusercontent.com/assets/111218/2838068/3d0d9b3a-d02a-11e3-8cf3-4f35dc4e8edc.png)


## Getting Started

* Clone the repository

* Install dependencies:
  ```
  $ bundle install
  ```
  
* Start Rails:
  ```console
  $ bundle exec rails s
  ```
  
* Visit [http://localhost:3000](http://localhost:3000)

## Deploy to Heroku

Read this first: [Getting Started with Rails 4.x and Heroku](https://devcenter.heroku.com/articles/getting-started-with-rails4)

* Launch a worker
  ```console
  $ heroku create
  ```
  

* Set the Google Analytics metadata:
  ```console
  $ heroku config:set GA_KEY=UA-123456789-ABC GA_ACCT=xyz
  ```
  
* Deploy
  ```console
  $ git push heroku master
  ```
