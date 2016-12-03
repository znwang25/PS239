# -*- coding: UTF-8 -*-
# Author: Zenan Wang
# Last Edit: 11/21/2016
# This file scrapes data from Sinica database to get biography for famous people during Ming and Qing dynasty.

# import required modules
import urllib.request
import sys
import re
import pandas as pd
import socket
import codecs
import time
# import numpy as np
from bs4 import BeautifulSoup

# Solves annoying encoding issues
if sys.stdout.encoding != 'UTF-8':
    sys.stdout = codecs.getwriter('utf-8')(sys.stdout.buffer, 'strict')
if sys.stderr.encoding != 'UTF-8':
    sys.stderr = codecs.getwriter('utf-8')(sys.stderr.buffer, 'strict')

# Create a header for output files
out_header = pd.DataFrame({"pid":"pid", "name": "name", "dynasty": "dynasty","year":"year", "alt_names": "alt_names","birth_place_old":"birth_place_old","birth_place_today":"birth_place_today","birthyr_ch": "birthyr_ch", "birthyr_en": "birthyr_en","career":"career" }, index=[0])
out_header.to_csv("../Data/bio_hist.csv", header=False, index=False, columns=["pid", "name", "dynasty","year", "alt_names","birth_place_old","birth_place_today","birthyr_ch", "birthyr_en","career"])

# Starting the scraping loop
for pid in range(1, 30038):
    # construct link, we can change pid at the end to access different page
    link = "http://archive.ihp.sinica.edu.tw/ttscgi/ttsquery?0:0:mctauac:NO%3DNO" + str(pid)
    print("starting",pid)
    # authinfo = urllib.request.HTTPBasicAuthHandler()
    # proxy_support = urllib.request.ProxyHandler({"http": "124.88.67.7:843"})
    # # build a new opener that adds authentication and caching FTP handlers
    # opener = urllib.request.build_opener(proxy_support, authinfo,
    #                                      urllib.request.CacheFTPHandler)
    # # install it
    # urllib.request.install_opener(opener)

    ## read the content of the server’s response
    headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:48.0) Gecko/20100101 Firefox/48.0'}
    req = urllib.request.Request(url = link, headers = headers)

    # Use urllib.request to retrieve webpage. Retry 5 times
    ntries = 5
    timeout = 45
    for _ in range(ntries):
        try:
            with urllib.request.urlopen(req, timeout=timeout) as response:
                content = urllib.request.urlopen(req, timeout=timeout).read()
                page_link = urllib.request.urlopen(req, timeout=timeout).geturl()
            break  # success
        except urllib.request.URLError as err:
            if not isinstance(err.reason, socket.timeout):
                raise  # propagate non-timeout errors
    else:  # all ntries failed
        print("all ntries failed")
        raise err  # re-raise the last timeout error

    # def get_encoding(soup):
    #     encod = soup.meta.get('charset')
    #     if encod == None:
    #         encod = soup.meta.get('content-type')
    #         if encod == None:
    #             content = soup.meta.get('content')
    #             match = re.search('charset=(.*)', content)
    #             if match:
    #                 encod = match.group(1)
    #             else:
    #                 raise ValueError('unable to find encoding')
    #     return encod
    # typeEncode = sys.getfilesystemencoding()

    ## This solves chinese encoding issues of the page
    # The pages should be all in "BIG5" encoding, but sometimes are encoded as utf-8
    try:
        src = content.decode("BIG5")
        # parse the response into an HTML tree
        soup = BeautifulSoup(src,"lxml")
    except UnicodeDecodeError:
        soup = BeautifulSoup(content, "lxml")

    # print(soup.prettify())

    ### Extract information from the soup now
    if soup.find(text=re.compile("目前找不到您要連結的資料"))==None: # If there is no error on the page
        # We only care about the table
        table = soup.find("table")
        # Get name of the person
        name = table.find("td", text=re.compile("姓名：")).parent.find_all("td")[1].text.strip().split(")")[1]
        # Get dynasty of the person lived in
        dynasty = table.find("td", text=re.compile("姓名：")).parent.find_all("td")[1].text.strip().split(")")[0].strip("(")

        # Get birthyear of the person, if such info exists
        if table.find("td", text=re.compile("中曆生卒：")) != None:
            birthyr_ch = table.find("td", text=re.compile("中曆生卒：")).parent.find_all("td")[1].text.strip()
        else:
            birthyr_ch = ""
        if table.find("td", text=re.compile("西曆生卒：")) != None:
            birthyr_en = table.find("td", text=re.compile("西曆生卒：")).parent.find_all("td")[1].text.strip()
        else:
            birthyr_en = ""

        # Get alias of the person, if such info exists
        if table.find("td", text=re.compile("異名：")) != None:
            alt_names = ",".join([alias.td.get_text() for alias in
                                  table.find("td", text=re.compile("異名：")).parent.table.find_all("tr")[1:]])
        else:
            alt_names = ""

        # Get birthplace of the person, if such info exists. BTW, GIS info may exist in birth_place_today.
        if table.find("td", text=re.compile("籍貫：")) != None:
            birth_place_old = \
            table.find("td", text=re.compile("籍貫：")).parent.find_all("td")[1].text.replace("\u3000", " ").split(" ")[0]
            birth_place_today = \
            table.find("td", text=re.compile("籍貫：")).parent.find_all("td")[1].text.replace("\u3000", " ").split(" ")[1]
        else:
            birth_place_old = ""
            birth_place_today = ""

        # Get career of the person, if such info exists.
        if table.find("td", text=re.compile("履歷：")) != None:
            career = [row.find_all("td")[0].text for row in
                      table.find("td", text=re.compile("履歷：")).parent.table.find_all("tr")[1:]]
            year_list = [row.find_all("td")[1].text for row in
                         table.find("td", text=re.compile("履歷：")).parent.table.find_all("tr")[1:]]
        else:
            career = ""
            year_list = ""

        ## Construct the dataframe to be outputed.
        head = pd.DataFrame({"pid": pid, "name": name, "dynasty": dynasty, "year": "", "alt_names": alt_names,
                             "birth_place_old": birth_place_old, "birth_place_today": birth_place_today,
                             "birthyr_ch": birthyr_ch, "birthyr_en": birthyr_en, "career": ""}, index=[pid, ])
        df = pd.DataFrame()
        # Construct a career panel for each individual
        for year in year_list:
            temp = head
            df = df.append(temp)
        df["year"] = year_list
        df["career"] = career
        # Output to csv file
        df.to_csv("../Data/bio_hist.csv", mode='a', header=False, index=False,
                  columns=["pid", "name", "dynasty", "year", "alt_names", "birth_place_old", "birth_place_today",
                           "birthyr_ch", "birthyr_en", "career"], encoding='utf-8')

        # Be gentle to the website, slow down the process
        if pid % 1000 == 0:
            time.sleep(30)
    else:
        print("Cannot find the page")
        continue

