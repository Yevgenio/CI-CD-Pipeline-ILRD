# Approved by Avihu

import unittest
from unittest.mock import patch, Mock
from main import clean_input
from provider import call_api, build_forecast, build_day
from secret import API_KEY

class TestProvider(unittest.TestCase):

    def test_clean_input(self):
        dirty = ' tel/aviv 1@ ]'
        clean = clean_input(dirty)
        self.assertEqual(clean, 'tel aviv')

    def test_call_api_response(self):
        response = call_api('berlin')
        self.assertNotEqual(response, None)

    def test_build_day(self):
        example = {
            "resolvedAddress": "paris",
            "irrelevant": "info",
            "days": [{
                "datetime": "2025-12-13",
                "tempmax": "8.8",
                "tempmin": "6.4",
                "humidity": "95.9",
                "icon": "cloudy",
                "something": "else.."
                }]
            }
        result = build_forecast(example)
        self.assertEqual(result["location"], "paris")
        self.assertEqual(result['forecast'][0]["icon"], "/static/icons/cloudy.png")
        self.assertEqual(result['forecast'][0]["date"], "13/12")

        

        
