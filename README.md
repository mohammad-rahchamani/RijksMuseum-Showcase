#  RijksMusem App

## Use Cases

### Load Feed From Remote API Use Case

#### Data:
- URL

#### Primary course:
1. Requests feed from remote API
2. Decodes data
3. Creates a list of feed items
4. Delivers feed items

#### Error course - network error
1. Delivers Error

#### Error course - decode error
1. Delivers Error

-------------

### Load From Local Feed Store Use Case

#### Primary course:
1. Reads data from the given URL
2. Decodes data
3. Creates a list of feed items and a timestamp
4. Delivers feed items and timestamp

#### Error course - store error (invalid url, ...)
1. Delivers Error

#### Error course - decode error
1. Delivers Error

-------------

### Delete Local Feed Store Use Case

#### Primary course:
1. Finishes successfully

#### Error course
1. Delivers error

-------------

### Save To Local Feed Store Use Case

#### Data:
- [FeedItem]
- Date (timestamp)

#### Primary course:
1. Encodes feed items and timestamp to json
2. Writes json data into store
3. Finishes successfully

#### Error course - store error (invalid url, ...)
1. Delivers error

#### Error course - encode error
1. Delivers error

-------------

### Load Feed From Cache Use Case

#### Data:
- TimeInterval (cache expiration)

#### Valid cache course:
1. Loads feed from local storage
2. Checks data for expiration
3. Delivers result

#### Empty cache from local storage course:
1. Deletes local storage data
2. Loads feed from remote loader
3. Writes data to local storage
4. Delivers data

#### Expired cache course:
1. Deletes local storage data
2. Loads feed from remote loader
3. Writes data to local storage
4. Delivers data

#### Local storage load error course:
1. Deletes local storage data
2. Loads feed from remote loader
3. Writes data to local storage
4. Delivers data

#### Load feed from remote loader error course:
1. Delivers error
 
#### Write to local storage error course:
1. Delivers data


### Payload Contract

```
{
    "links": {
        "self": "http://www.rijksmuseum.nl/api/en/collection/SK-C-6",
        "web": "http://www.rijksmuseum.nl/en/collection/SK-C-6"
    },
    "id": "en-SK-C-6",
    "objectNumber": "SK-C-6",
    "title": "The Sampling Officials of the Amsterdam Drapers’ Guild, Known as ‘The Syndics’",
    "hasImage": true,
    "principalOrFirstMaker": "Rembrandt van Rijn",
    "longTitle": "The Sampling Officials of the Amsterdam Drapers’ Guild, Known as ‘The Syndics’, Rembrandt van Rijn, 1662",
    "showImage": true,
    "permitDownload": true,
    "webImage": {
        "guid": "2c1ac367-9b11-4266-bb08-eea14ca0bb76",
        "offsetPercentageX": 0,
        "offsetPercentageY": 0,
        "width": 3000,
        "height": 1975,
        "url": "https://lh3.googleusercontent.com/gShVRyvLLbwVB8jeIPghCXgr96wxTHaM4zqfmxIWRsUpMhMn38PwuUU13o1mXQzLMt5HFqX761u8Tgo4L_JG1XLATvw=s0"
    },
    "headerImage": {
        "guid": "5f71570b-21d2-4f00-9219-edb93137110c",
        "offsetPercentageX": 0,
        "offsetPercentageY": 0,
        "width": 1920,
        "height": 460,
        "url": "https://lh3.googleusercontent.com/8vtyRTsJdGXuZhnHl5wF6vBgDNInw3q56DFYYr0Rzm1JJYNRl2iSIC30d_erXkTe_Yv8uJq1ZL56zFrXUpTFJrBDcbE=s0"
    },
    "productionPlaces": []
}
```

