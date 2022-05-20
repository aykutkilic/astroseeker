import os
import json
import traceback
from urllib import response

from flatlib import const
from flatlib.datetime import Datetime
from flatlib.geopos import GeoPos
from flatlib.chart import Chart
from flask import Flask, jsonify, request
import logging as log


def convertObject(o, root_level=True):
    result = {
        'type': o.type,
        'lat': o.lat,
        'lon': o.lon,
        'sign': o.sign,
        'signlon': o.signlon,
        'latspeed': o.latspeed,
        'lonspeed': o.lonspeed,
        'orb': o.orb(),
        # 'gender': o.gender(),
        # 'meanMotion': o.meanMotion(),
        'movement': o.movement(),
        'isDirect': o.isDirect(),
        'isPlanet': o.isPlanet(),
        'isRetrograde': o.isRetrograde(),
        'isStationary': o.isStationary(),
    }

    if root_level is True:
        result['antiscia'] = convertObject(o.antiscia(), False)
        result['cantiscia'] = convertObject(o.cantiscia(), False)

    return result


def convertObjects(chart):
    def _o(o):
        return convertObject(o)

    return {k: _o(v) for k, v in chart.objects.content.items()}


def convertHouse(h):
    return {
        'type': h.type,
        'num': h.num(),
        'lat': h.lat,
        'lon': h.lon,
        'sign': h.sign,
        'signlon': h.signlon,
        'size': h.size,
        'isAboveHorizon': h.isAboveHorizon()
    }


def convertHouses(chart):
    def _h(e):
        return convertHouse(chart.get(e))

    return [
        _h(const.HOUSE1),
        _h(const.HOUSE2),
        _h(const.HOUSE3),
        _h(const.HOUSE4),
        _h(const.HOUSE5),
        _h(const.HOUSE6),
        _h(const.HOUSE7),
        _h(const.HOUSE8),
        _h(const.HOUSE9),
        _h(const.HOUSE10),
        _h(const.HOUSE11),
        _h(const.HOUSE12)
    ]


def convertAngle(e, is_root=True):
    result = {
        'type': e.type,
        'id': e.id,
        'lat': e.lat,
        'lon': e.lon,
        'sign': e.sign,
        'signlon': e.signlon,
        'orb': e.orb()
    }

    if is_root:
        result['antiscia'] = convertAngle(e.antiscia(), False),
        result['cantiscia'] = convertAngle(e.cantiscia(), False)

    return result


def convertAngles(chart):
    def _a(e):
        return convertAngle(e)

    return {k: _a(v) for k, v in chart.angles.content.items()}


def convertFixedStar(s):
    return {
        'type': s.type,
        'lat': s.lat,
        'lon': s.lon,
        'mag': s.mag,
        'sign': s.sign,
        'signlon': s.signlon,
        'orb': s.orb()
    }


def convertFixedStars(chart):
    def _s(e):
        return convertFixedStar(chart.getFixedStar(e))

    return {s: _s(s) for s in const.LIST_FIXED_STARS}


def get_chart_data(date, time, gmt, lat, lon):
    chart = Chart(Datetime(date, time, gmt), GeoPos(lat, lon))
    result = {
        'general': {
            'hsys': chart.hsys,
            'pos': {'lat': chart.pos.lat, 'lon': chart.pos.lon},
            'moonphase': chart.getMoonPhase(),
            'isDiurnal': chart.isDiurnal(),
            'isHouse10MC': chart.isHouse10MC(),
            'isHouse1Asc': chart.isHouse1Asc(),
        },
        'objects': convertObjects(chart),
        'houses': convertHouses(chart),
        'angles': convertAngles(chart),
        'fixedStars': convertFixedStars(chart)
    }
    return json.dumps(result, indent=4)


app = Flask(__name__)

cities = None


def build_cities_dict():
    log.info(f'Building cities db. cwd:{os.getcwd()}')

    global cities
    with open('cities.txt') as f:
        loaded = json.load(f)
    cities = {i['name']: i for i in loaded}
    log.info(f'Loaded {len(cities)} cities in DB.')


# http://127.0.0.1:8080/natal?date=1984/01/01&time=22:45&gmt=+03:00&city_lat=41.01&city_lon=28.58
@app.route("/natal")
def natal_chart_data():
    def error_response(message, **kwargs):
        response = jsonify({'message': message, **kwargs})
        response.status_code = 404
        response.status = 'error.Bad Request'
        return response

    date = request.args.get('date')  # e.g. '1980/05/25'
    time = request.args.get('time')  # e.g. '20:15'
    gmt = request.args.get('gmt')  # e.g. '+03:00'
    city_lat = request.args.get('city_lat')  # e.g. 41.01
    city_lon = request.args.get('city_lon')  # e.g. 28.58
    if date is None:
        return error_response('date must be provided. e.g. 1984/01/01')
    if time is None:
        return error_response('time must be provided. e.g. 22:45')
    if gmt is None:
        return error_response('gmt must be provided. e.g. +03:00')
    if city_lat is None:
        return error_response('city_lat must be provided. e.g. 41.01')
    if city_lon is None:
        return error_response('city_lon must be provided. e.g. 28.58')

    try:
        city_lat = float(city_lat)
        city_lon = float(city_lon)
        return get_chart_data(date, time, gmt, city_lat, city_lon)
    except Exception as e:
        return error_response('failed with exception', traceback=traceback.format_exc(limit=32))

@app.route("/city")
def city():
    pass

if __name__ == "__main__":
    build_cities_dict()
    app.run(debug=True, host="0.0.0.0", port=int(os.environ.get("PORT", 8080)))
