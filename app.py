from flask import Flask, request, jsonify
from flask_cors import CORS
import mysql.connector

app = Flask(__name__)
CORS(app) # Membenarkan sambungan dari Frontend HTML

# Konfigurasi Pangkalan Data MySQL (XAMPP Default)
db_config = {
    'host': 'localhost',
    'user': 'root',
    'password': '',
    'database': 'smhms_db'
}

API_KEY = "SMHMS_SECRET_API_KEY_2026"

def get_db_connection():
    return mysql.connector.connect(**db_config)

# -------------------------------------------------------------
# 1. API: Menerima Data Sensor dari ESP32 & Paparan Dashboard
# -------------------------------------------------------------
@app.route('/api/sensor', methods=['GET', 'POST'])
def handle_sensor():
    key = request.args.get('api_key')
    if key != API_KEY:
        return jsonify({"status": "error", "message": "API Key tidak sah!"}), 403

    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    # ESP32 menghantar data baharu (POST)
    if request.method == 'POST':
        data = request.json
        water = data.get('water_level', 0)
        gas = data.get('gas_level', 0)
        fire = data.get('fire_detected', 0)

        # Logik penentuan status bahaya
        if fire == 1 or water <= 15 or gas > 3500:
            status = "DANGER"
        elif water <= 30 or gas > 2500:
            status = "WARNING"
        else:
            status = "NORMAL"

        query = """INSERT INTO sensor_logs (water_level, gas_level, fire_detected, status_hazard) 
                   VALUES (%s, %s, %s, %s)"""
        cursor.execute(query, (water, gas, fire, status))
        conn.commit()
        
        cursor.close()
        conn.close()
        return jsonify({"status": "success", "message": "Data berjaya disimpan ke MySQL!"})

    # Frontend mendapatkan bacaan terkini (GET)
    else:
        query = "SELECT * FROM sensor_logs ORDER BY id DESC LIMIT 1"
        cursor.execute(query)
        result = cursor.fetchone()
        
        cursor.close()
        conn.close()

        if result:
            return jsonify({"status": "success", "data": result})
        return jsonify({"status": "success", "data": {"water_level": 0, "gas_level": 0, "fire_detected": 0, "status_hazard": "NORMAL"}})

# -------------------------------------------------------------
# 2. API: Memuatkan Sejarah Log untuk analytics.html
# -------------------------------------------------------------
@app.route('/api/logs', methods=['GET'])
def get_logs():
    key = request.args.get('api_key')
    if key != API_KEY:
        return jsonify({"status": "error", "message": "API Key tidak sah!"}), 403

    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    
    query = "SELECT id, DATE_FORMAT(created_at, '%Y-%m-%d %H:%i:%s') as created_at, water_level, gas_level, fire_detected, status_hazard FROM sensor_logs ORDER BY id DESC LIMIT 50"
    cursor.execute(query)
    logs = cursor.fetchall()

    cursor.close()
    conn.close()
    return jsonify({"status": "success", "data": logs})

# -------------------------------------------------------------
# 3. API: Log Masuk Pengguna (login.html)
# -------------------------------------------------------------
@app.route('/api/login', methods=['POST'])
def login():
    data = request.json
    email = data.get('email')
    password = data.get('password')

    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    query = "SELECT name, email, role FROM users WHERE email = %s AND password = %s"
    cursor.execute(query, (email, password))
    user = cursor.fetchone()

    cursor.close()
    conn.close()

    if user:
        return jsonify({"status": "success", "user": user})
    else:
        return jsonify({"status": "error", "message": "E-mel atau kata laluan salah!"}), 401

# -------------------------------------------------------------
# 4. API: Pendaftaran Akaun Baharu (login.html)
# -------------------------------------------------------------
@app.route('/api/register', methods=['POST'])
def register():
    data = request.json
    name = data.get('name')
    email = data.get('email')
    password = data.get('password')
    role = data.get('role', 'user')

    conn = get_db_connection()
    cursor = conn.cursor()

    try:
        query = "INSERT INTO users (name, email, password, role) VALUES (%s, %s, %s, %s)"
        cursor.execute(query, (name, email, password, role))
        conn.commit()
        return jsonify({"status": "success", "message": "Pendaftaran berjaya!"})
    except mysql.connector.Error as err:
        return jsonify({"status": "error", "message": "E-mel telah digunakan!"}), 400
    finally:
        cursor.close()
        conn.close()

if __name__ == '__main__':
    # Jalankan server API pada port 5000
    app.run(host='0.0.0.0', port=5000, debug=True)