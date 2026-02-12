FROM python:3.9

WORKDIR /code
COPY . /code
RUN pip install --no-cache-dir -r requirements.txt

EXPOSE 8080

# Start Flask using Gunicorn
CMD ["gunicorn", "-w", "4", "-b", "0.0.0.0:8080", "main:app"]
