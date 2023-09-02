
# Backyarder - BE

## Deployed at: https://backyarder-be-47454958a7d2.herokuapp.com/


## Authors

### Kim Bergstrom
#### [GitHub](https://github.com/kbergstrom78) | [LinkedIn](https://www.linkedin.com/in/kimberley-bergstrom/)

### Boston Lowrey
#### [GitHub](https://github.com/BLowrey24) | [LinkedIn](https://www.linkedin.com/in/boston-lowrey/)

### Myles Nottingham
#### [GitHub](https://github.com/MylesNottingham) | [LinkedIn](https://www.linkedin.com/in/mylesnottingham/)

### Austin Woods
#### [GitHub](https://github.com/boomclear) | [LinkedIn](https://www.linkedin.com/in/austin-woods-1830aa195/)

## Tech Stack

**Server:** 
 - Ruby (language)
 - Sinatra (framework)

## Gems

- dotenv-rails
  - Documentation for dotenv-rails can be found here: https://www.rubydoc.info/gems/dotenv-rails/2.1.1
     
- Faraday
  - Used for HTTP request to APIs 
  - Documentation for Faraday can be found here: https://lostisland.github.io/faraday/#/

- Figaro
  - Used to mask API key(s) from files. 
  - Documentation for Figaro can be found here: https://rubygems.org/gems/figaro/versions/1.1.1

- jsonapi-serializer
 - Provides fast JSON serialization of API objects according to the JSON:API specification.
 - Documentation for jsonapi-serializer can be found here: https://www.rubydoc.info/gems/jsonapi-serializers/0.8.0

- pg
    - Provides support for using PostgreSQL as your database.
    - Documentation for pg can be found at: https://www.rubydoc.info/gems/pg
- Rack
    - A low-level interface for web frameworks in Ruby, providing the underlying functionality used by Sinatra and Rails.
    - Documentation for Rack can be found at: https://www.rubydoc.info/gems/rack/Rack

- rack-cors
    - Middleware for handling Cross-Origin Resource Sharing (CORS) in Rack-compatible web apps.
    - Documentation for rack-cors can be found here: https://www.rubydoc.info/gems/rack-cors/0.4.0

- rack-test
    - Provides methods for testing Rack-based apps.
    - Documentation for rack-test can be found at: https://www.rubydoc.info/github/brynary/rack-test/Rack/Test/Methods

- Tux
    - A command-line tool for interacting with your Sinatra app's environment.
    - Documentation for Tux can be found here: https://github.com/cldwalker/tux

## Installation
- Backyarder-BE requires an API key from the Perenual.com.  You can follow the steps to get the required credentials at: https://perenual.com/docs/api
  - Once you have the required credentials, make an .env file at the root directory and put the credentials in that .env file.
   - PERENUAL_API_KEY = <Your_api_key>
- 





### Get info for one plant
 GET '/api/v1/plants/:id’

Request:
```
  {
    "plantId": 1
  }
```
 Response:
```
{
  data: {
    {
      "id": 1,
      "image": "https://perenual.com/storage/species_image/1_abies_alba/og/1536px-Abies_alba_SkalitC3A9.jpg",
      "common_name": "European Silver Fir",
      "scientific_name": ["Abies alba"],
      "type": "tree",
      "leaf_color": ["green"],
      "cycle": "Perennial",
      "watering": "Frequent",
      "sunlight": ["full sun"],
      "hardiness": {
        "min": "7",
        "max": "7"
      },
      "section": [
        {
          "id": 1,
          "type": "sunlight",
          "description": "Sunlight is the most important environmental factor..."
        },
        {
          "id": 3,
          "type": "watering",
          "description": "Watering European silver fir trees is essential..."
        }
      ],
      "pruning_month": ["March", "April"],
      "attracts": ["bees", "birds", "rabbits"],
      "flowering_season": ["Spring"],
      "edible_fruit": false,
      "maintenance": "Low",
      "poisonous_to_pets": false,
      "drought_tolerant": false,
      "invasive": false,
      "indoor": false
    }
  }
}
```
### Get a list of plants
 GET '/api/v1/plants'
 Response:
```
  {
    data: [
        {
            "id": 1,
            "name": "European Silver Fir",
            "image_thumbnail": "https://perenual.com/storage/species_image/1_abies_alba/thumbnail/1536px-Abies_alba_SkalitC3A9.jpg",
            "type": "tree",
            "sunlight": ["full sun"],
            "hardiness": "2"
        },
        {
            "id": 2,
            "name": "Another Plant",
            "image_thumbnail": "https://example.com/path/to/thumbnail.jpg",
            "type": "flower",
            "sunlight": ["partial shade"],
            "hardiness": "4"
        },
        // ... (more plant objects)
    ]
  }
```
### Place a plant
 PATCH /api/v1/placement 
```
{
  cell: "C4",
  plant_id: 1,
  status: false
}
```
200 Response
```
{ "data": {
    "id": 1,
    "type": "placement",
    "attributes": {
      "cell": "C4",
      "plant_id": 1,
      "plant_image": "www.google.com",
      "sunlight": "low",
      "common_name": "Tree",
      "scientific_name": "Treesius",
      "watering_period": "morning",
      "watering_general_benchmark": "5-7 days",
      "type": "tree",
      "sunlight": "Part shade",
      "pruning_interval": "1 yearly",
      "attracts":[
        "bees",
        "birds",
        "rabbits"
      ],
      "flowers": true,
      "flowering_season": "Spring",
      "fruits": false,
      "edible_fruit": false,
      "growth_rate": "High",
      "maintenance": "Low",
      "poisonous_to_humans": false,
      "poisonous_to_pets": false,
      "drought_tolerant": false,
      "sunlight_description": "Sunlight is the most important environmental factor controlling the growth and health of European silver fir (Abies alba). This species naturally grows in open, sunny habitats and is adapted to full sunlight or partial shade. Without adequate sunlight, the needles of a silver fir will fail to produce adequate amounts of chlorophyll, a key determinant of essential photosynthesis.\n\nWhen exposed to sunlight, the foliage of a European silver fir is usually thick, dense and lush. The needles are usually a deep green color, although in some areas the needles may take on a bluish hue. Sun-exposed needles are typically more abundant and tightly packed than those in more shaded areas. Furthermore, needles of silver fir trees normally grow more rapidly when exposed to direct sunlight.\n\nThe bark of a European silver fir exposed to direct sunlight typically has a more rugged and weathered appearance. Sun-exposed bark may contain lichens and moss, which act as a natural form of sun protection. In areas where the silver fir is shaded, the bark is typically smoother and lighter in color.\n\nSunlight is essential for the optimal growth and health of a European silver fir. Although this species can survive in both full sun and partial shade, it typically performs best when exposed to adequate sunlight.",
      "watering_description": "Watering European silver fir trees is essential for them to stay healthy. It is important to provide them with regular watering, especially during their first growing season, as they need to establish a good root system. A weekly deep watering is all they need, but they should be more frequently watered during periods of drought and heat. The soil should always be kept moist but never soggy.\n\nIf they are planted in a container, they should be watered more frequently as they can dry out quickly in containers. The soil should be kept moist but never overly wet. Overwatering can lead to root rot, so be sure not to overwater. When watering a container grown European Silver Fir, wait for the top 1-2 inches of soil to dry out before watering again.\n\nMulching around a European silver fir is a great way to help with water retention and help the soil stay moist. An organic mulch, such as wood chips or shredded bark, can help to keep the soil from drying out and also help reduce the amount of time spent watering. It also helps suppress weeds and keeps the roots protected from extreme temperatures.\n\nOverall, regular and consistent watering is important for young European silver fir trees to help them grow and thrive."
                },
      "hardiness": {
          "min": "7",
          "max": "7"
      },
      "status": "planted"
  }
}
```
