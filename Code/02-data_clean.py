# -*- coding: UTF-8 -*-
# Author: Zenan Wang
# Last Edit: 11/29/2016
# This file cleans the scraped data. For this class, I will only focus on the GIS infomation of the birth place.

# import required modules
import sys
import re
import pandas as pd
import socket
import codecs
import time

# Import the scraped data
data = pd.read_csv("../Data/bio_hist.csv")
# Separate GIS information from 'birth_place_today' variable
birth_plz_gis = data['birth_place_today'].str.strip("()").str.split('(',expand=True)
birth_place_today=birth_plz_gis[0].str.split(':',expand=True)[1]
birth_plz_gis[["lon","lat"]] = birth_plz_gis[1].str.split(',',expand=True)

data['birth_place_today']=birth_place_today
data[["lon","lat"]]=birth_plz_gis[["lon","lat"]]
data["name"]=data["name"].str.strip("()")

# Output the data
data.to_csv("../Data/bio_hist_gis.csv",index=False, columns=["pid", "name", "dynasty", "year", "career","alt_names", "birthyr_ch", "birthyr_en","birth_place_old", "birth_place_today",
                          "lon","lat" ], encoding='utf-8')