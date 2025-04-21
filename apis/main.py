from flask import Flask, jsonify, request
import docker

app = Flask(__name__)

# Initialize Docker client
docker_client = docker.from_env()

@app.route('/')
def home():
    return jsonify({"message": "Docker Stats API is running"}), 200

# Endpoint to fetch stats for all containers
@app.route('/containers/stats', methods=['GET'])
def get_all_container_stats():
    try:
        # Get all containers
        containers = docker_client.containers.list(all=True)
        stats_list = []

        # Collect stats for each container
        for container in containers:
            try:
                stats = container.stats(stream=False)
                stats_list.append({
                    "id": container.short_id,
                    "name": container.name,
                    "image": container.image.tags[0] if container.image.tags else "N/A",
                    "status": container.status,
                    "cpu_usage": calculate_cpu_usage(stats),
                    "memory_usage": stats.get('memory_stats', {}).get('usage', 0),
                    "memory_limit": stats.get('memory_stats', {}).get('limit', 0),
                    "net_io": calculate_net_io(stats)
                })
            except Exception as e:
                # Handle errors for individual containers
                stats_list.append({
                    "id": container.short_id,
                    "name": container.name,
                    "error": str(e)
                })

        return jsonify(stats_list), 200

    except Exception as e:
        return jsonify({"error": str(e)}), 500

# Endpoint to fetch stats for a specific container
@app.route('/containers/<container_id>/stats', methods=['GET'])
def get_single_container_stats(container_id):
    try:
        # Get specific container
        container = docker_client.containers.get(container_id)
        stats = container.stats(stream=False)

        # Prepare stats response
        stats_response = {
            "id": container.short_id,
            "name": container.name,
            "image": container.image.tags[0] if container.image.tags else "N/A",
            "status": container.status,
            "cpu_usage": calculate_cpu_usage(stats),
            "memory_usage": stats.get('memory_stats', {}).get('usage', 0),
            "memory_limit": stats.get('memory_stats', {}).get('limit', 0),
            "net_io": calculate_net_io(stats)
        }

        return jsonify(stats_response), 200

    except docker.errors.NotFound:
        return jsonify({"error": f"Container with ID {container_id} not found"}), 404
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# Helper function to calculate CPU usage
def calculate_cpu_usage(stats):
    try:
        cpu_stats = stats.get('cpu_stats', {}).get('cpu_usage', {})
        pre_cpu_stats = stats.get('precpu_stats', {}).get('cpu_usage', {})

        # Calculate CPU delta
        cpu_delta = cpu_stats.get('total_usage', 0) - pre_cpu_stats.get('total_usage', 0)
        system_cpu_delta = stats.get('cpu_stats', {}).get('system_cpu_usage', 0) - stats.get('precpu_stats', {}).get('system_cpu_usage', 0)

        # Calculate CPU percentage
        if system_cpu_delta > 0.000:
            cpu_usage = (cpu_delta / system_cpu_delta) * len(cpu_stats.get('percpu_usage', [])) * 100.0
            return round(cpu_usage, 3)
        else:
            return 0.000
    except KeyError:
        return 0.000

# Helper function to calculate network I/O
def calculate_net_io(stats):
    try:
        net_io = stats.get('networks', {})
        rx = sum(interface.get('rx_bytes', 0) for interface in net_io.values())
        tx = sum(interface.get('tx_bytes', 0) for interface in net_io.values())
        return {"rx_bytes": rx, "tx_bytes": tx}
    except KeyError:
        return {"rx_bytes": 0, "tx_bytes": 0}

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)