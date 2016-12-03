# /*Authors: Zenan Wang */
# /*Created: 11/29/2016 */
# /*Last edited: 11/29/2016*/

# This file cleans GIS data and visualize the data

# Load libraries
x <- c("rgdal", "rgeos", "sp", "maptools", "rasterVis", "tidyverse","magrittr","raster", "parallel", "doParallel", "foreach", "haven","readxl")

# install.packages(x) # warning: uncommenting this may take a number of minutes
lapply(x, library, character.only = TRUE) # load the required packagesgetwd

# Sets encoding to utf-8, solves encoding issues
getCPLConfigOption("SHAPE_ENCODING")
setCPLConfigOption("SHAPE_ENCODING", "UTF-8")
# Importing China county boundary GIS data
china_cnty <- readOGR(dsn="../Data/1999County",layer="BOUNT_poly")
# Change projection into WGS84
china_cnty %<>% spTransform( CRS("+init=epsg:4326"))

# Now cleaning the data I scraped
bio_gis <- read_csv("../Data/bio_hist_gis.csv")
data <- bio_gis[c("lon","lat","pid","birthyr_en","dynasty")]
# Fixed some problems in GIS information. Those human inputing errors.
# Examples are placing the dot at the wrong place
data%<>%group_by(pid) %>% filter(row_number(lon) == 1)
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

bio_pts <- ToSpatialPoint(data)

# saveRDS(bio_pts, file="../Data/bio_pts.rds")
# saveRDS(china_cnty, file="../Data/china_cnty.rds")

# Aggregate the biography data onto county level, counting how many people falling into each county
bio_agg <- aggregate(x = bio_pts["pid"], by = china_cnty, FUN = length)
# add this into the china_cnty dataset
china_cnty$n_bios <-bio_agg$pid

# Importing night light data
# Note: raw night light data is from NOAA, but data used here has been cropped by myself for other project.
light05.chn <- raster("../Data/light05chn.tif")
# Increase by a factor of 20 to 10*10 arcminutes,approxmiately 18.5km (1 minute is 1.852 km )
light05.chn <- aggregate(light05.chn,fact=20, fun=mean)
# Change raster to polygon
light <- rasterToPolygons(light05.chn)
# Change projection into WGS84
light %<>% spTransform( CRS("+init=epsg:4326"))
# Give it a name
names(light@data) <- "light"
# Aggregate the biography data onto county level, averaging the level of luminosity of the county at night
light_agg <- aggregate(x = light["light"], by = china_cnty, FUN = mean)
# add this into the china_cnty dataset
china_cnty$light <-light_agg$light

# Graphical analysis
# Need to fortify the spatial data in order to plot in ggplot
cnty_f <- fortify(china_cnty)
china_cnty$id <- row.names(china_cnty)
cnty_f <- left_join(cnty_f, china_cnty@data)
cnty_f$log_n<-log(cnty_f$n_bios) 
cnty_f$log_light<-log(cnty_f$light) 

# Visualize spatial distribution of those records
ggplot(data=as.data.frame(bio_pts), aes(x=lon, y=lat))+geom_point(color="red")+geom_polygon(data=china_cnty, aes(x=long, y=lat, group=group),fill=NA, color="black",size=0.05)
ggsave("../Results/fig1_bio_pts.png")

# Visualize spatial distribution of the record after aggregating to county level
ggplot(data=cnty_f, aes(x=long, y=lat, group=group,fill=log_n))+
  geom_polygon(color="black",size=0.05)+ scale_fill_gradient2( low = "#001a4d",mid = "#0066FF", high = "yellow",na.value = "#001a4d",midpoint = 3)
ggsave("../Results/fig2_bio_county.png")

# Visualize the raw raster data of night light
gplot(light05.chn,maxpixels=1440000)+
  geom_tile(aes(fill=value), alpha=0.8)+
  scale_fill_gradient2( low = "#001a4d",mid = "#0066FF", high = "yellow",na.value = "#001a4d",midpoint = 30)+
  coord_equal()
ggsave("../Results/fig3_light_raw.png")

# Visualize spatial distribution of the night light after aggregating to county level
ggplot(data=cnty_f, aes(x=long, y=lat, group=group,fill=log_light))+
  geom_polygon(color="black",size=0.05)+  scale_fill_gradient2( low = "#001a4d",mid = "#0066FF", high = "yellow",na.value = "#001a4d",midpoint = -1.5)
ggsave("../Results/fig4_light_county.png")

# Simple regression analysis
data_reg <- china_cnty@data
reg <- lm(light~n_bios,data_reg)
summary(reg)
library(stargazer)
stargazer(reg, type = "html",out = "../Results/reg_results.html",
 title = "Number of records and 2005 night light level",
 covariate.labels = "Number of records during Ming and Qing",
          dep.var.labels   = " Night light level in 2005")

# Visualize the regression
ggplot(data=data_reg,aes(x=n_bios, y=light))+geom_point()+scale_x_log10()+scale_y_log10()+ geom_smooth(method="lm")
ggsave("E:/Dropbox/Academic/PhD/PS239T/project/reg.png")
