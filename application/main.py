'''
Weather App main file
Handles the web server and routing
'''
import re
from flask import Flask, request, render_template, redirect
from prometheus_client import Counter, generate_latest
from provider import weather_provider

app = Flask(__name__)
home_visit = Counter('home', 'Page visit', ['page'])
result_returned = Counter('result', 'Results returned', ['page'])

def clean_input(location):
    '''since the API is very forgiving only a simple cleanup is needed 
    mainly to make sure we dont break the route with chars like / '''
    clean = re.sub(r'[1234567890!@#$%^&*()=_+-/.,`~:;?"\'[\]{}><\\]', ' ', location)
    clean = re.sub(r'\s+', ' ', clean).strip()
    return clean.strip()


@app.route('/', methods =["GET", "POST"])
def home():
    '''the page you see when first entering the website homepage'''
    home_visit.labels(page='home').inc()

    if request.method == 'POST':
        location = request.form.get('location')
        location = clean_input(location)
        return redirect('/'+location)
    return render_template("page.html",
                        input_provided=False,
                        data=None)


@app.route('/<location>')
def location_page(location):
    '''the page you go when '''
    result_returned.labels(page=location).inc()

    data = weather_provider(location)
    return render_template("page.html",
                           input_provided=True,
                           location=location,
                           data=data)

@app.route('/metrics')
def metrics():
    return generate_latest()

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
