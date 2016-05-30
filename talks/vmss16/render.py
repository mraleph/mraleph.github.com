#!/usr/bin/env python

#
# Generate png slides from HTML slides.
#

import time
from selenium import webdriver

browser = webdriver.Chrome()
browser.set_window_size(1024,720 + (720 - 646))
browser.get('http://localhost:8000/talks/goto2015/')

print browser.execute_script("return document.documentElement.clientWidth")
print browser.execute_script("return document.documentElement.clientHeight")
time.sleep(5)

slide = 0
while True:
  time.sleep(0.5)
  browser.save_screenshot('slides/slide-%d.png' % (slide))
  if browser.execute_script("return Reveal.isLastSlide()"):
    break
  slide = slide + 1
  browser.execute_script("Reveal.next()")
  if slide % 10 == 0:
    print slide

browser.quit()