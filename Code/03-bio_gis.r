# /*Authors: Zenan Wang */
# /*Created: 11/29/2016 */
# /*Last edited: 11/29/2016*/

# This file cleans GIS data and visualize the data

# Load libraries
x <- c("rgdal", "rgeos", "sp", "sf", "maptools", "rasterVis", "tidyverse","magrittr","raster", "parallel", "doParallel", "foreach", "haven","readxl")

# install.packages(x) # warning: uncommenting this may take a number of minutes
lapply(x, library, character.only = TRUE) # load the required packagesgetwd

# Sets encoding to utf-8, solves encoding issues
getCPLConfigOption("SHAPE_ENCODING")
setCPLConfigOption("SHAPE_ENCODING", "UTF-8")
# Importing China county boundary GIS data
china_cnty <- readOGR(dsn="Data/1999County",layer="BOUNT_poly")
# Change projection into WGS84
china_cnty <- china_cnty %>% 
  spTransform( CRS("+init=epsg:4326"))%>%
  st_as_sf%>%
  st_set_crs(4326)%>%
  st_simplify  

# Now cleaning the data I scraped
bio_gis <- read_csv("Data/bio_hist_gis.csv")
data <- bio_gis%>%select(lon, lat,pid, birthyr_en, dynasty)%>%
  group_by(pid) %>% filter(row_number() == 1) %>% ungroup
# Fixed some problems in GIS information. Those are human inputing errors.
# Examples are placing the dot at the wrong place
data[which(data$lon==1053.6),"lon"] <- 105.36
# or reversing the order of the longitutde and latitude 
temp <- data[which(data$lat>90),c("lon","lat")]
data[which(data$lat>90),c("lon","lat")] <- c(temp["lat"],temp["lon"])
data[which(data$lon<70),"lon"] <- 100+data[which(data$lon<70),"lon"]

# Convert the dataframe into spatial points.
ToSpatialPoint <- function(data){
  # This function will transform the bio location data to gps point. 
  ### Get long and lat from data.frame. Make sure that the order is in lon/lat.
  xy <- data[c("lon","lat")]
  #  Dropping NAs
  xy %<>%filter(!is.na(lon),!is.na(lat))
  data%<>%filter(!is.na(lon),!is.na(lat))
  bio_pts <- SpatialPointsDataFrame(coords=xy, data=as.data.frame(data),proj4string = CRS("+init=epsg:4326"))
  return(bio_pts)
}

bio_pts <- ToSpatialPoint(data)%>%st_as_sf%>%st_set_crs(4326)


bio_pts%>% write_rds("Data/bio_pts.rds")
china_cnty%>%saveRDS("Data/china_cnty.rds")

# Aggregate the biography data onto county level, counting how many people falling into each county
bio_agg <- aggregate(x = bio_pts['pid'], by = china_cnty, FUN = length)
# add this into the china_cnty dataset
china_cnty$n_bios <-bio_agg$pid

# Importing night light data
# Note: raw night light data is from NOAA, but data used here has been cropped by myself for other project.
light05.chn <- raster("Data/light05chn.tif")
# Increase by a factor of 20 to 10*10 arcminutes,approxmiately 18.5km (1 minute is 1.852 km )
light05.chn <- aggregate(light05.chn,fact=20, fun=mean)
# Change raster to polygon and Change projection into WGS84
light <- rasterToPolygons(light05.chn)%>% spTransform( CRS("+init=epsg:4326"))%>%
  st_as_sf%>%
  st_set_crs(4326)
# Give it a name
light <- light%>% rename(light=light05chn)
# Aggregate the biography data onto county level, averaging the level of luminosity of the county at night
light_agg <- aggregate(x = light["light"], by = china_cnty, FUN = mean)
# add this into the china_cnty dataset
china_cnty$light <-light_agg$light

# Graphical analysis
# Need to fortify the spatial data in order to plot in ggplot
china_cnty <- china_cnty%>%mutate(log_n = log(n_bios), log_light=log(light))

# Visualize spatial distribution of those records
ggplot(china_cnty)+
  geom_sf(size=0.1)+
  geom_sf(data = bio_pts,color='red',size=0.1)+
theme_bw()+
  theme(panel.grid.major = element_blank(),
        panel.grid.minor = element_blank())
ggsave("Results/fig1_bio_pts.png")

# Visualize spatial distribution of the record after aggregating to county level
ggplot(china_cnty)+
  geom_sf(size=0.1,aes(fill = log_n))+
  scale_fill_gradient(low = "#fff7ec", high = "#d7301f",na.value = 'NA')+
  theme_bw()+
  theme(panel.grid.major = element_blank(),
        panel.grid.minor = element_blank())
ggsave("Results/fig2_bio_county.png")

# Visualize the raw raster data of night light
gplot(light05.chn,maxpixels=1440000)+
  geom_tile(aes(fill=value), alpha=0.8)+
  scale_fill_gradient2( low = "#081d58",mid = "#0066FF", high = "yellow", na.value = 'NA',midpoint = 30)+
  theme_bw()+
  theme(panel.grid.major = element_blank(),
        panel.grid.minor = element_blank())
ggsave("Results/fig3_light_raw.png")

# Visualize spatial distribution of the night light after aggregating to county level
ggplot(china_cnty)+
  geom_sf(size=0.1, aes(fill = log_light))+
  scale_fill_gradient2( low = "#081d58",mid = "#0066FF", high = "yellow", na.value = 'NA',midpoint = -2)+
  theme_bw()+
    theme(panel.grid.major = element_blank(),
          panel.grid.minor = element_blank())
ggsave("Results/fig4_light_county.png")

# Simple regression analysis
reg <- lm(light~n_bios,china_cnty)
summary(reg)
library(stargazer)
stargazer(reg, type = "html",out = "Results/reg_results.html",
 title = "Number of records and 2005 night light level",
 covariate.labels = "Number of records during Ming and Qing",
          dep.var.labels   = " Night light level in 2005")

# Visualize the regression
ggplot(data=china_cnty,aes(x=n_bios, y=light))+
  geom_point()+scale_x_log10()+scale_y_log10()+ geom_smooth(method="lm")
ggsave("Results/reg.png")
