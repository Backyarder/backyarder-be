
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




## API Reference

### Get API check
GET '/api/v1/'

Response:
```
Welcome to Backyarder!
```

### Get Plant Index
GET '/api/v1/plants'

Response:
```
{
  "data": [
    {
      "id": null,
      "type": "list",
      "attributes": {
        "image": "https://perenual.com/storage/species_image/2692_echinacea_tomato_soup/thumbnail/red-orange-echinacea-echinacea-cone-flower-medicinal.jpg",
        "name": "coneflower",
        "hardiness": {
          "min": "3",
          "max": "8"
        },
        "type": "Flower",
        "sunlight": [
          "Full sun",
          "part shade"
        ],
        "plant_id": 2692
      }
    },
    {
      "id": null,
      "type": "list",
      "attributes": {
        "image": "https://perenual.com/storage/species_image/2699_echinops_ritro/thumbnail/52315581367_1406967d9d_b.jpg",
        "name": "small globe thistle",
        "hardiness": {
          "min": "3",
          "max": "8"
        },
        "type": "Thistle",
        "sunlight": [
          "Full sun"
        ],
        "plant_id": 2699
      }
    },
    // ... (more plant objects)
  ]
}
```

### Get Plant Details
GET '/api/v1/plants/:id’

Request:
```
{
  "plant_id": 1
}
```

 Response:
```
{
  "data": {
    "id": null,
    "type": "detail",
    "attributes": {
      "plant_id": 1,
      "image": "https://perenual.com/storage/species_image/1_abies_alba/regular/1536px-Abies_alba_SkalitC3A9.jpg",
      "common_name": "European Silver Fir",
      "scientific_name": [
        "Abies alba"
      ],
      "type": "tree",
      "leaf_color": [
        "green"
      ],
      "cycle": "Perennial",
      "watering": "Frequent",
      "sunlight": [
        "full sun"
      ],
      "hardiness": {
        "min": "7",
        "max": "7"
      },
      "pruning_month": [
        "February",
        "March",
        "April"
      ],
      "attracts": [],
      "flowering_season": [],
      "edible_fruit": false,
      "maintenance": null,
      "poisonous_to_pets": false,
      "drought_tolerant": false,
      "invasive": false,
      "indoor": false,
      "section": [
        {
          "id": 109,
          "type": "watering",
          "description": "European Silver Fir 'Abies Alba' should be watered about once a week, depending on the season and weather conditions. During the growing season (spring to mid-summer), water deeply and thoroughly. For the rest of the year, water only when the soil is dry. When watering, ensure that the root system is saturated. Do not over-water, as this can lead to root rot."
        },
        {
          "id": 110,
          "type": "sunlight",
          "description": "European Silver Fir 'Abies Alba' is a species of coniferous tree that grows best in sunny areas. This species of plant requires a minimum of 6 hours of sunlight per day throughout the growing season. Ideally, it should receive up to 8 hours of direct sunlight in the summer months, and 4-5 hours of sunlight in the winter. It is important to note that European Silver Fir 'Abies Alba' is not tolerant of shade and may be damaged if exposed to too much shade."
        },
        {
          "id": 111,
          "type": "pruning",
          "description": "European Silver Fir should be pruned in the late winter to early spring months. This species should be pruned lightly and selectively, removing any dead, diseased, or broken branches. Foliage and branches that cross over 1 another should also be removed. Generally, pruning should not exceed 1/3 of the total height and width of the tree. When pruning, begin from the bottom of the tree and steadily move upwards."
        }
      ]
    }
  }
}
```

### Get Garden
GET '/api/v1/garden'

 Response:
```
{
  "data": [
    {
      "id": "501",
      "type": "cell",
      "attributes": {
        "image": null,
        "plant_name": null,
        "location_id": "A1",
        "status": "empty",
        "plant_id": null,
        "updated_at": "09/02/2023 20:45"
        }
    },
    {
      "id": "502",
      "type": "cell",
      "attributes": {
        "image": null,
        "plant_name": null,
        "location_id": "A2",
        "status": "empty",
        "plant_id": null,
        "updated_at": "09/02/2023 20:45"
      }
    },
    {
      "id": "503",
      "type": "cell",
      "attributes": {
        "image": null,
        "plant_name": null,
        "location_id": "A3",
        "status": "empty",
        "plant_id": null,
        "updated_at": "09/02/2023 20:45"
      }
    },
    // ... (more cell objects)
  ]
}
```

### Patch a Cell
PATCH /api/v1/cell

#### Place a Plant
```
{
  "location_id": "A1",
  "status": 1,
  "plant_id": 13,
  "image": "image_url",
  "plant_name": "Weedy Weed"
}
```

200 Response

```
{
  "data": {
    "id": "501",
    "type": "cell",
    "attributes": {
      "image": "image_url",
      "plant_name": "Weedy Weed",
      "location_id": "A1",
      "status": "placed",
      "plant_id": 13,
      "updated_at": "09/02/2023 23:11"
    }
  }
}
```

#### Remove a Plant
```
{
  "location_id": "A1",
  "action": "remove_plant"
}
```

200 Response

```
{
  "data": {
    "id": "501",
    "type": "cell",
    "attributes": {
      "image": null,
      "plant_name": null,
      "location_id": "A1",
      "status": "empty",
      "plant_id": null,
      "updated_at": "09/02/2023 23:17"
    }
  }
}
```

#### Disable a Cell
```
{
  "location_id": "A2",
  "action": "disable_cell"
}
```

200 Response

```
{
  "data": {
    "id": "502",
    "type": "cell",
    "attributes": {
      "image": null,
      "plant_name": null,
      "location_id": "A2",
      "status": "disabled",
      "plant_id": null,
      "updated_at": "09/02/2023 23:20"
    }
  }
}
```

### Delete Garden
DELETE /api/v1/garden
(Clears all cells in the garden with status of 'placed')

200 Response

### Delete All
DELETE /api/v1/all
(Clears all cells in the garden)

200 Response

### Get Garden Stats
GET /api/v1/garden-stats

Response
```
{
  "Bushy Bush": { "count": 2, "image": "image_url_1" },
  "Weedy Weed": { "count": 5, "image": "image_url_2" },
  "Treey Tree": { "count": 1, "image": "image_url_3" }
}
```
