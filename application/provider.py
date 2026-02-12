'''
Provider module
Handles data retrieval and caching
future: add real database support
'''
from datetime import date, datetime
from pathlib import Path
import json
import requests
from prometheus_client import Summary

from secret import API_KEY

cwd = Path(__file__).parent

api_time = Summary('duration_compute_seconds', 'Time spent in the compute() function')

def load_cache():
    '''load cache from local JSON file'''
    print('LOG: Loading cache file.')
    try:
        with open(cwd / 'cache.json', 'r', encoding='utf-8') as file:
            data = json.load(file)
            print("LOG: Cache file found.")
            return data
    except FileNotFoundError:
        print('LOG: Cache file not found')
        return None

@api_time.time()
def call_api(location):
    '''get new data by making an API call'''
    print("LOG: Requesting updated data from API.")

    api_url = "https://weather.visualcrossing.com/VisualCrossingWebServices/rest/services/timeline/"
    params = {
        "unitGroup": "metric",
        "include": "days", # "days,hours"
        "key": API_KEY,
        "contentType": "json"
    }
    try:
        response = requests.get(api_url + location, params=params, timeout=5)
    except requests.Timeout:
        print("LOG: Error: API request timed out")
        return None
    except requests.RequestException as e:
        print(f"LOG: Error: API request failed with exception {e}")
        return None

    if response.status_code == 200:
        data = response.json()
        print("LOG: Successfully retrieved data from API.")
    else:
        print(f"LOG: Error: API request failed with status code {response.status_code}")
        data = None
    return data

def update_cache(data, location):
    '''backup forecast for the next few days'''
    try:
        with open(cwd / 'cache.json', 'r', encoding='utf-8') as file:
            db = json.load(file)
    except FileNotFoundError:
        db = {}
    db[location] = data
    with open(cwd / 'cache.json', 'w', encoding='utf-8') as file:
        print('LOG: Writing updated cache to disk')
        json.dump(db, file, indent=4)


def extract_location(data, location):
    '''check if cache has data from today on the location'''
    if data is None  \
        or data.get(location, None) is None \
        or str(data[location]['timestamp']) != str(date.today()):
        print("LOG: Input location not in cache.")
        return None

    print("LOG: Input location found in cache.")
    return data[location]


def build_day(day):
    '''takes a day object, filters and translates it to needed format'''
    date_str = datetime.strptime(day['datetime'], "%Y-%m-%d").strftime("%d/%m")
    temp_day = str(day['tempmax']) + "°C"
    temp_night = str(day['tempmin']) + "°C"
    humidity = str(day['humidity']) + "%"
    icon = "/static/icons/" + day['icon'] + ".png"
    return {
        'date': date_str,
        'temp_day': temp_day,
        'temp_night': temp_night,
        'humidity': humidity,
        'icon': icon
    }


def build_forecast(data):
    '''construct final payload to be injected to HTML'''
    if data is None:
        return None

    days = data['days'][:7]
    forecast = [build_day(day) for day in days]
    output = {
        'timestamp': str(date.today()),
        'location': data['resolvedAddress'],
        'forecast': forecast
    }
    return output


def weather_provider(location):
    '''this is the heart of the module'''
    cache = load_cache()
    forecast = extract_location(cache, location)
    if forecast is None:
        data = call_api(location)
        forecast = build_forecast(data)
        update_cache(forecast, location)
    return forecast
