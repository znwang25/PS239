# PS239
PS239 project

## Short Description

This projects scrapes data from Taiwan Sinica's website, and use the spatial information in the data to show some graphs.

[Results](Results/slide.md)

## Dependencies

1. R,
2. Python, version 3.5, Anaconda distribution.

## Files

#### Data

1. bio\_hist.csv: Contains data from the Taiwan Sinica collected via get_biohist.py. Includes information on records of famous people during Ming and Qing dynasty. This files is using UTF-8 encoding.
2. bio\_hist_gis.csv: The final Analysis Dataset after cleaning bio\_hist.csv.
3. light05chn.tif: Night light raster data in 2005 for China, raw data from NOAA.
4. 1999County: Shapfiles for Chinese county borders.

#### Code

1. 01-get_biohist.py: Scrapes the Sinica website to get historical biography data
2. 02-data_clean.R: Cleans the raw datasets scraped.
2. 03-bio_gis.R: Conducts descriptive analysis of the data, producing the tables and visualizations found in the Results directory.

#### Results

1. fig1\_bio_pts.png: Visualize spatial distribution of those historical records.
2. fig2\_bio_county.png: Visualize spatial distribution of the record after aggregating to county level.
3. fig3\_light_raw.png: Visualize the raw raster data of night light. 
4. fig4\_light_county.png: Visualize spatial distribution of the night light after aggregating to county level.
5. reg\_results.html: Simple regression result.
6. reg.png: Visualize the regression.

