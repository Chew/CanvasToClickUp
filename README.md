# Canvas To ClickUp

A converter from Canvas to-do to ClickUp tasks.

This is more of a proof of concept since it relies a little to heavily on my own Canvas instance I use for college.

## How It Works

When the program is ran (via `ruby canvas_to_clickup.rb`) it will do the following:

1) Get the list of to-dos from Canvas
   i) Due to API limitations, this will only get anything due within the next week
2) If there are to-do list items, get the tasks from ClickUp
3) Compare the "Canvas Link" custom field on the to-do list items to the ClickUp tasks
   i) If there is a match, update the task with the to-do list item's "Title", "Description", and "Due Date"
   ii) If there is no match, create a new task with the to-do list item's information.
4) Execution is over!

## How I Wrote It

You can read more about how I set this up in my [dev.to]() article.

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

0) `cp config.example.yml config.yml` then fill out the config.yml file
1) `bundle install`
2) `ruby canvas_to_clickup.rb` (only need this step once 0-1 and done)
