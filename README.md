# Canvas To ClickUp

A converter from Canvas to-do to ClickUp tasks.

This is more of a proof of concept since it relies a little to heavily on my own Canvas instance I use for college.

## New To ClickUp?

If this is the first time you're hearing about ClickUp, great! Click this image to get started. The best part? It's free!

<a href="https://clickup.com?fp_ref=chew35" target="_blank" style="outline:none;border:none;"><img src="https://d2gdx5nv84sdx2.cloudfront.net/uploads/s73xa6xt/marketing_asset/banner/4159/leaderboard_v1.png" alt="clickup" border="0"/></a>

## How It Works

When the program is ran (via `ruby canvas_to_clickup.rb`) it will do the following:

1) Retrieve active courses from Canvas. This is any course whose term is active.
2) Get the list of all assignments from the active courses.
3) Get all tasks from ClickUp.
4) Compare the "Canvas Link" custom field on the to-do list items to the ClickUp tasks
   i) If there is a match, update the task with the item's "Title", "Description", "Due Date", and "Status"
   ii) If there is no match, create a new task with the item's information.
5) Execution is over!

The program is very verbose and will print out the results of each step, if there are any.

## How I Wrote It

You can read more about how I set this up in my [dev.to]() article. (soon, I forgor to write it)

## Personal Setup

This program is sorta tailored to my instance, but if you can somehow replicate (or fix) this setup, it may be useful!

Pre-requisites:
- ClickUp Account and Space
- Canvas Account and Instance (usually through a school)
- A ClickUp List with the following setup:
    - Custom Fields Enabled
      - Enabled Fields: "Canvas Link" (URL) and "Class" (Dropdown)
      - The class dropdown should be whatever classes you have. By default, this is exactly the same as the name on Canvas.
    - Due Date Time ClickApp Enabled
    - Statuses: "To Do", "Submitted", and "Graded"
- Ruby

1) `cp config.example.yml config.yml` then fill out the config.yml file
2) `cp custom.example.rb custom.rb` then fill out the custom.rb file, if you wish.
3) `bundle install`
4) `ruby canvas_to_clickup.rb` (only need this step once 1-3 are done)
