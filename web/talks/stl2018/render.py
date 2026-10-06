#!/usr/bin/env python

#
# Generate png slides from HTML slides.
#

import time
from selenium import webdriver
from selenium.webdriver.common.desired_capabilities import DesiredCapabilities


#firefox_capabilities = DesiredCapabilities.FIREFOX
#firefox_capabilities['marionette'] = True
#firefox_capabilities['binary'] = '/Applications/FirefoxNightly.app/Contents/MacOS/firefox'

#browser = webdriver.Firefox(capabilities=firefox_capabilities)

browser = webdriver.Chrome()
browser.set_window_size(1280,720 + (720 - 646))
browser.get('http://localhost:8000/talks/stl2018/')

time.sleep(5)

slide = 0
while True:
  time.sleep(0.5)
  browser.save_screenshot('slides/slide-%03d.png' % (slide))
  if browser.execute_script("return Reveal.isLastSlide()"):
    break
  slide = slide + 1
  browser.execute_script("Reveal.next()")
  if slide % 10 == 0:
    print slide

browser.quit()