# Set libraries
library(tidyr)
library(dplyr)
library(readr)
library(forcats)
library(purrr)
library(tibble)
library(jsonlite)
library(httr)
library(data.table)
library(rcrossref)
library(taxize)
library(stringr)
library(fs)
library(mangal)

#------------------------------
  # Metadata
#------------------------------

lat  <- 40.828245
lon  <- -72.9993
srid <- 4326

folder_name <- "woodwell_1967" # Name of the subfolder in mangal-datasets
food_web_name <- "WEB3"

name_file <- read_csv("~/Documents/UBO/Cours/Semestre 8/Stage/Mangal/Trophic-metacommunities-master/Trophic_metacom_meta_analysis/Data/name_dictionary.csv",
                      col_type = cols(.default = col_character())) %>%
  filter( web %in% food_web_name) %>%
  split(.$web)
# Must fill all CAP fields; null fields optional

attr_inter <- list(name        = "Presence/Absence",
                   table_owner = "interactions",
                   description = "DESCRIPTION",
                   unit        = "NA")

# attr1 <- list(name        = "NAME",
#               table_owner = "TABLE_OWNER",
#               description = "DESCRIPTION",
#               unit        = "NA")

# attr2 <- list(name        = "NAME",
#               table_owner = "TABLE_OWNER",
#               description = "DESCRIPTION",
#               unit        = "NA")

ref <- list(doi       = "10.1038/scientificamerican0367-24",
             jstor     = "NA",
             pmid      = "NA",
             paper_url = "https://doi.org/10.1038%2Fscientificamerican0367-24",
             data_url  = "https://globalwebdb.com/",
             author    = "George M. Woodwell",
             year      = "1967",
             bibtex    = "@article{Woodwell_1967,doi = {10.1038/scientificamerican0367-24},url = {https://doi.org/10.1038%2Fscientificamerican0367-24}, year = 1967, month = {mar},	publisher = {Springer Nature}, volume = {216}, number = {3}, pages = {24--31}, author = {George M. Woodwell},	title = {Toxic Substances and Ecological Cycles}, journal = {Scientific American}}")


users <- list(name         = "Clément VIOLET",
              email        = "clement.violet@etudiant.univ-brest.fr",
              orcid        = "0000-0001-6217-5891",
              organization = "Université de Bretagne Occidentale",
              type         = "administrator")


# enviro <- list(name  = "attribute name",
#                lat   = lat,
#                lon   = lon,
#                srid  = srid,
#                date  = "1111-11-11",
#                value = 0)


dataset <- list(name        = "woodwell_1967",
                 date        = "1967-01-01",
                 description = "Plant and animals interaction in Long Islands estuary",
                 public      = TRUE)


# trait <- list(date = "1111-11-11")


network <- list(name             = "woodwell_1967",
                 date             = "1967-01-01",
                 lat              = lat,
                 lon              = lon,
                 srid             = srid,
                 description      = "Plant and animals interaction in Long Islands estuary",
                 public           = TRUE,
                 all_interactions = FALSE)


inter <- list(taxon_1_level = "taxon",
              taxon_2_level = "taxon",
              date          = "1967-01-01",
              direction     = "directed",
              # type          = "predation",
              method        = "biblio",
              description   = "null",
              public        = TRUE,
              lat           = lat,
              lon           = lon,
              srid          = srid)


#------------------------------
# Cleaning matrix
#------------------------------

# Open file

## Species file

# sp_name <- read_table(file = paste0("mangal-datasets/",folder_name,"/raw/",folder_name,"_species_name.PRN")) %>%
#   # select_if(is.character(.))# Read the file
#   select(3) %>% # Only the third column got the species names.
#   slice(1:nrow(.)-1) %>% # Last line is a full NA. Remove it
#   unlist() %>% # Breaking df into vector
#   unname() %>%
#   as.factor() %>% 
#   fct_inorder() # Reorder factor


# data_matrice <- paste0("mangal-datasets/",folder_name,"/raw/",folder_name,"_food_web.DAT") %>%
#   map(~read_table(.x, skip  = 0, col_names = FALSE, col_type = cols(.default = col_character()), na = "")) %>%
#   map(~rename(.x, sp_id = X1))
# data_matrice[[1]][1,1] <- NA # Remove file identifier use  NA value

data_matrice <- paste0("~/Documents/UBO/Cours/Semestre 8/Stage/Mangal/Trophic-metacommunities-master/Trophic_metacom_meta_analysis/interaction matrices/",
                       food_web_name, ".csv") %>%
  map(~read_csv(.x, skip  = 1, col_names = FALSE, col_type = cols(.default = col_character()), na = "")) %>%
  map(~rename(.x, sp_id = X1))
data_matrice[[1]][1,1] <- NA # Remove file identifier use  NA value

# data_col_name <- data_matrice %>%
#   map(~slice(.x,1)) %>% # Select first line of each df to create column with name of species
#   modify(~select(.x, -1)) %>% # Remove the column sp id to convert
#   map(~unlist(.x)) %>% # Breaking each df into vector
#   map(~as.integer(.x)) %>% # Coerce to integer linking it to sp_name
#   map(~{.x <- levels(sp_name)[.x]})

data_col_name <- data_matrice %>%
  map(~slice(.x,1)) %>% # Select first line of each df to create column with name of species
  modify(~select(.x, -1)) %>% # Remove the column sp id to convert
  map(~unlist(.x)) %>% # Breaking each df into vector
  map(~unname(.x))

# data_row_name <- data_matrice %>%
#   map(~filter(.x, !is.na(select(.x,1)))) %>% # Remove the line containing all sp id
#   map(~select(.x, 1)) %>%  # Select the column containing the species integer in its row
#   map(~unlist(.x)) %>% # Breaking each df into vector
#   map(~as.integer(.x)) %>% # Coerce to integer linking it to sp_name
#   map(~{.x <- levels(sp_name)[.x]}) # Apply the correct level to the corect sp number.

data_row_name <- data_matrice %>%
  map(~filter(.x, !is.na(select(.x,1)))) %>% # Remove the line containing all sp id
  map(~select(.x, 1)) %>%  # Select the column containing the species integer in its row
  map(~unlist(.x)) %>%
  map(~unname(.x))


FW_name <- data_matrice %>% # Construct the Food Web matric to inject
  map(~filter(.x, !is.na(select(.x,1)))) %>%
  map2(modify(data_row_name, ~.x), ~mutate(.x, sp_id = .y)) %>%
  map(~column_to_rownames(.x, "sp_id")) %>% # Store sp name as row name
  map2(modify(data_col_name, ~.x), ~{`names<-`(.x, .y)}) %>%
  map(~rownames_to_column(.x, "sp_taxon_1")) %>%
  map(~gather(.x, "sp_taxon_2", "value", -sp_taxon_1)) %>% #Convert large df to long format
  map(~filter(.x, value != 0)) %>%# Remove 0 interaction
  map(~mutate(.x, type = ifelse(str_detect(.x$sp_taxon_1, "(.*[Pp]lant.*)|(.*[Aa]lgae.*)|(.*[Pp]hytoplan.*)|(.*[Dd]iatoms.*)|(.*[Dd]inofl.*)")
                                , "herbivory", "predation"))) %>% # Add type interaction
  map(~mutate(.x, type = ifelse(str_detect(.x$sp_taxon_1, "(.*[Dd]ebris.*)|(.*[Dd]etri*)"), "commensalism", .x$type)))

#------------------------------
# Set taxo_back and taxa table
#------------------------------
# Create taxo_back_df

## Get Unique taxa of data
# taxa <- FW_name %>%
#   map(~select(.x, sp_taxon_1, sp_taxon_2)) %>%
#   map(~gather(.x, id, sp)) %>%
#   modify(~deframe(.x)) %>%
#   map(~unique(.x)) %>%
#   map(~enframe(.x, name = NULL, value = "sp")) %>%
#   map(~mutate(.x, id = row_number())) # Create an id to reorder the tab

taxa <- FW_name %>%
  map(~select(.x, sp_taxon_1, sp_taxon_2)) %>%
  map(~gather(.x, id, sp)) %>%
  modify(~deframe(.x)) %>%
  map(~unique(.x)) %>%
  map(~enframe(.x, name = NULL, value = "original_name"))

## Checking taxa and creating taxa_df

sp_name_for_this_web <- name_file %>%
  map(~select(.x, original_name, scientific_name)) %>%
  map(~mutate(.x, scientific_name = if_else(is.na(.x$scientific_name), original_name, scientific_name))) %>%
  map(~deframe(.x))

taxa_df <- taxa %>%
  map2(sp_name_for_this_web, ~mutate(.x, name_clear = str_replace_all(.x$original_name, .y))) %>%
  map(~mutate(.x, name_clear = paste0(str_to_upper(str_extract(.x$name_clear, ".{1}")), str_remove(.x$name_clear, ".{1}")))) %>%
  map(~mutate(.x, name_clear = str_remove_all(.x$name_clear, "\\s\\(.*\\)$")))

# taxa_corrected <- taxa %>%
#   map(~mutate(.x, sp = str_remove_all(.x$sp, "\\s\\(.*\\)$"))) %>% # Correct vernacular name at the lowest level possible (species)
#   map(~mutate(.x, sp = str_replace_all(.x$sp, c("bay shrimp" = "Crangon", "silversides" = "Alestiidae",
#                              "mud snail" = "Omphiscola glabra", "clam" = "Bivalvia",
#                              "mosquito" = "Culicidae", "cricket" = "Gryllidae",
#                              "eel" = "Anguilliformes", "fluke" = "Pleuronectiformes",
#                              "blowfish" = "Tetraodontidae", "minnow 1" = "Cyprinidae 1",
#                              "minnow 2" = "Cyprinidae 2", "tern" = "Sterninae",
#                              "Osprey" = "Pandionidae", "Green Heron" = "Butorides virescens",
#                              "merganser" = "Mergus", "cormorant" = "Phalacrocoracidae",
#                              "gull" = "Laridae", "kingfisher" = "Alcedinidae",
#                              "Red-winged Blackbird" = "Agelaius phoeniceus"))))
# 
# taxa_checked <- taxa_corrected %>%
#   map(~.x$sp) %>%
#   map(~gnr_resolve(.x, canonical = FALSE, best_match_only = T)) # Check for wrong names
# taxa_name_not_known <- taxa_checked %>%
#   map(~attributes(.x)$not_known) %>% # Names not recognized by Global Names Recognition and Discovery.
#   map(~enframe(.x, name = NULL, value = "user_supplied_name")) %>% # Create a df simillar to sp_name_cleaned to bind it whith sp_name_cleaned
#   map(~mutate(.x, submitted_name = paste0(str_to_upper(str_extract(.x$user_supplied_name, ".{1}")), str_remove(.x$user_supplied_name, ".{1}")))) %>%
#   map(~mutate(.x, matched_name = submitted_name,
#               data_source_title = NA_character_,
#               score = NA_real_))
# 
# taxa_df <-  taxa_checked %>%
#   map2(taxa_name_not_known, ~bind_rows(.x, .y)) %>%
#   map(~select(.x, user_supplied_name, matched_name)) %>%
#   map2(taxa_corrected, ~left_join(.x, .y, by = c("user_supplied_name" = "sp"))) %>%
#   map(~select(.x, -1)) %>% 
#   map2(taxa, ~right_join(.x, .y, by = "id")) %>%
#   map(~select(.x, sp, matched_name)) %>%
#   map(~`names<-`(.x, c("original_name", "name_clear")))
# 
# taxa_df[[1]]$`name_clear`[1] <- "Organic debris" # Manually editing some wrong name added by Global Names Recognition and Discovery


## Select only taxa not yet in db

server <- "http://poisotlab.biol.umontreal.ca"

taxa_back_df <- taxa_df %>%
  map(~unlist(.x$name_clear)) %>%
  map(~unname(.x)) %>%
  flatten_chr() %>%
  unique() %>%
  map_chr(~{modify_url(server, path = paste0("/api/v2/","taxonomy/?name=", str_replace_all(.x, " ", "%20")))}) %>%
  map_chr(~str_replace_all(.x, ".*,%20.*", "_")) %>%
  map_chr(~str_replace_all(.x, ".*%20-%20.*", "-")) %>%
  map_chr(~str_replace_all(.x, "\\.%20", "__")) %>%
  keep(~length(content((GET(url = .x, config = add_headers("Content-type" = "application/json","Authorization" = paste("bearer", readRDS("mangal-datasets/.httr-oauth"))))))) == 0) %>%
  map_chr(~str_remove_all(.x, fixed("http://poisotlab.biol.umontreal.ca/api/v2/taxonomy/?name="))) %>%
  map_chr(~str_replace_all(.x, fixed("%20"), " ")) %>%
  map_chr(~str_replace_all(.x, fixed("__"), ". ")) %>%
  map_chr(~str_replace_all(.x, fixed("_"), ", "))

taxa_back_df <- taxa_back_df %>%
  enframe(name = NULL, value = "name") %>%
  mutate(bold = as.double(unlist({map(.$name,~get_boldid(.x, row = 5, verbose = FALSE)[1])})),
         eol = NA_real_, #Add NA in eol column : See taxize issue : #718 EOL: maybe completely remove the data source from taxize
         tsn = as.double(unlist({map(.$name,~get_tsn(.x, row = 5, verbose = FALSE)[1])})),
         ncbi = as.double(unlist({map(.$name,~get_uid(.x, row = 5, verbose = FALSE, key = "679d0a26947d9b6432371b268ec0c7b39b08")[1])}))) # Add API KEy for NCBI

#------------------------------
# Set traits table
#------------------------------

# trait_df <- read.csv2(file = "mangal-datasets/FW_name/data/FW_name_trait.csv", header = TRUE)

# trait_df <- melt(trait_df, id.vars = c("taxon"), na.rm = TRUE)
# names(trait_df) <- c("taxon", "name", "value")

#------------------------------
# Writing taxa and interaction table
#------------------------------

write.csv2(x = taxa_back_df, file = paste0("mangal-datasets/", folder_name,"/data/",folder_name, "_taxa_back.csv"), row.names = FALSE)

if(is.null(names(taxa_df)) == TRUE){ # Control flow statement if there is multiple dataset in this paper.
  
  taxa_df %>%
    walk(~write.csv2(x = taxa_df, file = paste0("mangal-datasets/", folder_name,"/data/",folder_name, "_taxa.csv"), row.names = FALSE))
  
}else{
  
  taxa_df %>%
    names() %>%
    walk(~write.csv2(x = taxa_df[[.]], file = paste0("mangal-datasets/", folder_name,"/data/",folder_name, "_", ., "_taxa.csv"), row.names = FALSE))
  
}

if(is.null(names(FW_name)) == TRUE){
  
  FW_name %>%
    walk(~write.csv2(x = FW_name, file = paste0("mangal-datasets/", folder_name,"/data/",folder_name, "_inter.csv"), row.names = FALSE))
  
}else{
  
  FW_name %>%
    names() %>%
    walk(~write.csv2(x = FW_name[[.]], file = paste0("mangal-datasets/", folder_name,"/data/",folder_name, "_", ., "_inter.csv"), row.names = FALSE))
}


# trait_df %>%
#   names() %>%
#   walk(~write.csv2(x = trait_df[[.]], file = paste0("mangal-datasets/", folder_name,"/data/",folder_name, "_", ., "_trait.csv"), row.names = FALSE))
# 
# taxa_back_df <-  paste0("mangal-datasets/", folder_name, "/data/", folder_name, "_taxa_back.csv") %>%
#   read_csv2(col_types = cols("c", "d", "d", "d", "d"))
# 
# taxa_df <-  paste0("mangal-datasets/", folder_name, "/data/") %>%
#   dir_ls() %>%
#   as.character() %>%
#   str_subset(fixed("taxa.csv")) %>%
#   map(~read_csv2(.x, col_types = cols("c", "c")))
# 
# FW_name <-  paste0("mangal-datasets/", folder_name, "/data/") %>%
#   dir_ls() %>%
#   as.character() %>%
#   str_subset(fixed("inter.csv")) %>%
#   map(~read_csv2(.x, col_types = cols("c", "c", "i")))
# 
# trait_df <-  paste0("mangal-datasets/", folder_name, "/data/") %>%
#   dir_ls() %>%
#   as.character() %>%
#   str_subset(fixed("trait.csv")) %>%
#   map(~read_csv2(.x, col_types = cols("c", "c", "d")))

#------------------------------
# Throwing injection functions
#------------------------------

POST_attribute(attr_inter)

# POST_attribute(attr1)
# POST_attribute(attr2)

POST_ref(ref)
POST_user(users)

# POST_environment(enviro, attr_##)

POST_dataset(dataset, users, ref)

# POST_network(network_lst = , enviro = enviro, dataset, users)
# POST_network(network_lst = inter, dataset, users) # Work
map(network, ~POST_network(network_lst = .x, dataset = dataset, users = users))


POST_taxa_back(taxa_back_df)
# POST_taxon(taxa_df) # Work
map(taxa_df, ~POST_taxon)

# POST_traits(trait_df, network)

# POST_interaction(inter_df = FW_name[[1]], inter = inter, enviro = enviro, attr = attr_inter, users)
# POST_interaction(inter_df = FW_name[[1]], inter = inter, attr = attr_inter, users) # work
map2(FW_name, inter, ~POST_interaction(inter_df = .x, inter = .y, attr = attr_inter, users))
rm(lat, lon, srid, attr_inter, ref, users, enviro, dataset, trait, network, inter, taxa_df, taxa_back_df, FW_name)