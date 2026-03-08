from genericpath import exists
import os
import json
import traceback
from urllib import response

from flatlib import const
from flatlib.datetime import Datetime
from flatlib.geopos import GeoPos
from flatlib.chart import Chart
from flask import Flask, jsonify, request
import logging as logger
import ahocorasick

logger.basicConfig(filename="out.log",
                filemode="w+",
                level=logger.DEBUG)

log = logger.getLogger('main')


def convertObject(o, root_level=True):
    result = {
        'type': o.type,
        'lat': o.lat,
        'lon': o.lon,
        'ra': o.eqCoords()[0] if hasattr(o, 'eqCoords') else 0,
        'dec': o.eqCoords()[1] if hasattr(o, 'eqCoords') else 0,
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
        try:
            return convertFixedStar(chart.getFixedStar(e))
        except:
            return None

    return {s: _s(s) for s in const.LIST_FIXED_STARS}


from datetime import datetime as std_datetime, timedelta

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
    return result


app = Flask(__name__)
automaton = ahocorasick.Automaton()
cities = None


def build_cities_dict():
    global automaton, cities

    log.info(f'Building cities db. cwd:{os.getcwd()}')

    path = 'cities.json'
    if not exists(path):
        path = 'backend/' + path
    with open(path) as f:
        loaded = json.load(f)
    cities = {i['ascii'].lower(): i for i in loaded}
    for i, city_name in enumerate(cities.keys()):
        automaton.add_word(city_name, (i, city_name))
        log.warn(city_name)

    automaton.make_automaton()

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
    steps_str = request.args.get('steps')
    step_minutes_str = request.args.get('step_minutes')

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
        
        if steps_str and step_minutes_str:
            steps = int(steps_str)
            step_minutes = int(step_minutes_str)
            dt_str = f"{date} {time}"
            dt_obj = std_datetime.strptime(dt_str, "%Y/%m/%d %H:%M")
            results = []
            for _ in range(steps):
                d_str = dt_obj.strftime("%Y/%m/%d")
                t_str = dt_obj.strftime("%H:%M")
                results.append(get_chart_data(d_str, t_str, gmt, city_lat, city_lon))
                dt_obj += timedelta(minutes=step_minutes)
            return json.dumps(results, indent=4)
        else:
            return json.dumps(get_chart_data(date, time, gmt, city_lat, city_lon), indent=4)
    except Exception as e:
        return error_response('failed with exception', traceback=traceback.format_exc(limit=32))


@app.route("/city")
def city():
    def error_response(message, **kwargs):
        response = jsonify({'message': message, **kwargs})
        response.status_code = 404
        response.status = 'error.Bad Request'
        return response
    global automaton, cities

    if cities is None:
        build_cities_dict()
    prefix = request.args.get('prefix')  # e.g. ist

    if prefix is None or len(prefix) < 3:
        return error_response('prefix must be provided and at least must be 3 characters')

    try:
        result = [cities[candidate] for candidate in automaton.keys(prefix)]
        return jsonify(result)
    except Exception as e:
        return error_response('failed with exception', traceback=traceback.format_exc(limit=32))


if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0", port=int(os.environ.get("PORT", 8080)))
