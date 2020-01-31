#!/usr/bin/env /data/mta4/miniconda3/envs/ska3/bin/python

import json
import requests
import urllib
import numpy as np
import pandas as pd
import time

### The following code is to calculate P2 and P5 (which are not P4 and P7 respectively)
# This is replacing goes_energetic_proton_flux_primary.txt also known as G13pchan_5m.txt
proton_diff_url = 'https://services.swpc.noaa.gov/json/goes/primary/differential-protons-1-day.json'
proton_diff_web = requests.get(proton_diff_url)
proton_data = pd.DataFrame(proton_diff_web.json())
#convert flux from keV to MeV
proton_data['flux'] = proton_data['flux'].multiply(1000)

proton_text = """:Created {}
# source: https://services.swpc.noaa.gov/json/goes/primary/differential-protons-1-day.json
# P1       1020-1860 keV
# P2A      1900-2300 keV
# P2B      2310-3340 keV
# P3       3400-6480 keV
# P4      5840-11000 keV
# P5     11640-23270 keV
# P6     25900-38100 keV
# P7     40300-73400 keV
# P8A    83700-98500 keV
# P8B   99900-118000 keV
# P8C  115000-143000 keV
# P9   160000-242000 keV
# P10  276000-404000 keV
# Source: GOES-{}

                                         5-minute GOES-{} Energetic Proton Flux Channels
                                         
{}
"""
creation_time = time.strftime('%Y %b %d %H%M %Z')
pd.options.display.float_format = '{:<2,.2e}'.format
satellite = proton_data['satellite'].unique()[0]
proton_table = proton_data.pivot_table(index = 'time_tag', columns='channel', values='flux')
proton_table = proton_table[['P1', 'P2A', 'P2B', 'P3', 'P4', 'P5', 'P6', 'P7', 'P8A', 'P8B', 'P8C', 'P9', 'P10']]
proton_2_hours = proton_table[-24:]
#proton_table

#dformatter = lambda x: '{:<2}'.format(x)
#pformatter = lambda x: '{:.2e}'.format(x)
#floatformatter = lambda x: '{:<2,.2e}'.format(x)
#all_format = [dformatter]*13
proton_2_hours_str =  proton_2_hours.to_string(justify = 'center')

output = proton_text.format(creation_time, satellite, satellite, proton_2_hours_str)

with open('proton_flux_channels.txt', 'w') as f:
    f.write(output)



### The following code is to calculate E>2MeV
# This is replacing goes_particle_flux_primary.txt otherwise know as G13_part_5m.txt
electron_text = """:Created {}
# source: https://services.swpc.noaa.gov/json/goes/primary/integral-electrons-1-day.json
# E>=2 MeV
# Source: GOES-{}

      5-minute GOES-{} Electron Flux
      
{}
"""
creation_time = time.strftime('%Y %b %d %H%M %Z')

electron_int_url = 'https://services.swpc.noaa.gov/json/goes/primary/integral-electrons-1-day.json'

electron_int_web = requests.get(electron_int_url)
electron_e_data = pd.DataFrame(electron_int_web.json())

satellite = electron_e_data['satellite'].unique()[0]
electron_e_table = electron_e_data.pivot_table(index = 'time_tag', columns = 'energy', values = 'flux')
electron_e_2_hours = electron_e_table[-24:]

electron_e_2_hours_str = electron_e_2_hours.to_string(justify = 'center')

output = electron_text.format(creation_time, satellite, satellite, electron_e_2_hours_str)
with open('electron_flux_2_mev.txt', 'w') as f:
    f.write(output)
