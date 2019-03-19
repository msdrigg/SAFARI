# -*- coding: utf-8 -*-
"""
Created on Tue Mar  5 11:13:36 2019

This runs all input files in the current directory
as safari runs. the runs are started sequencially,
where the next run is started when the first one
finishes.

@author: Patrick
"""

import os
import subprocess
import time

directory = '.'

for filename in os.listdir(directory):
    if filename.endswith(".input") and not filename==('safari.input'):
        saf_file = open('safari.input', 'w')
        saf_file.write(filename.replace('.input', ''))
        saf_file.close()
        print(os.path.join(directory, filename))
        subprocess.call('Safari.exe', shell=True)
        #Wait a second before next run
        time.sleep(1)