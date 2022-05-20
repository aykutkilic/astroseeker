import json
import os

cities = []

with open('backend/cities1000.txt') as f:
    for line in f.readlines():
        fields = line.split('\t')
        if(int(fields[14]) < 50000):
            continue
        cities.append({
            'geonameid': int(fields[0]),
            'name': fields[1],
            'ascii': fields[2],
            'country': fields[8],
            'lat': float(fields[4]),
            'lon': float(fields[5]),
            'population': int(fields[14]),
            'timezone': fields[17]
        })


with open('backend/cities.json', 'w') as f:
    json.dump(cities, f, indent=4)
