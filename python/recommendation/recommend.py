import pandas as pd
from sklearn.tree import DecisionTreeRegressor
from sklearn.preprocessing import OneHotEncoder
import json
import sys

def load_model():
    # Datos sintéticos
    data = {
        'Tarea': ['Investigación', 'Estudio', 'Ejercicio', 'Viaje', 'Trabajo'],
        'Clásica': [0.5, 0.3, 0.0, 0.4, 0.2],
        'Lo-fi': [0.3, 0.5, 0.2, 0.4, 0.3],
        'Electrónica': [0.0, 0.0, 0.6, 0.0, 0.1],
        'Jazz': [0.2, 0.2, 0.1, 0.2, 0.3],
        'Rock': [0.0, 0.0, 0.1, 0.0, 0.1]
    }

    df = pd.DataFrame(data)
    encoder = OneHotEncoder(sparse_output=False)
    X = encoder.fit_transform(df[['Tarea']])
    y = df[['Clásica', 'Lo-fi', 'Electrónica', 'Jazz', 'Rock']]

    model = DecisionTreeRegressor(random_state=0)
    model.fit(X, y)

    return model, encoder

def get_recommendations(task_type):
    model, encoder = load_model()
    X_nueva = encoder.transform([[task_type]])
    pred = model.predict(X_nueva)[0]

    # Obtener géneros recomendados (los 3 más probables)
    genre_probabilities = {
        'Clásica': pred[0],
        'Lo-fi': pred[1],
        'Electrónica': pred[2],
        'Jazz': pred[3],
        'Rock': pred[4]
    }

    # Ordenar géneros por probabilidad
    sorted_genres = sorted(
        genre_probabilities.items(),
        key=lambda x: x[1],
        reverse=True
    )

    # Tomar los 3 géneros más probables
    recommended_genres = [g[0] for g in sorted_genres[:3]]
    probabilities = [g[1] for g in sorted_genres[:3]]

    # Calcular score de confianza (promedio de las 3 probabilidades más altas)
    confidence_score = sum(probabilities) / len(probabilities)

    return {
        'genre_probabilities': genre_probabilities,
        'recommended_genres': recommended_genres,
        'confidence_score': confidence_score
    }

if __name__ == '__main__':
    # Leer datos de entrada desde stdin
    input_data = json.loads(sys.stdin.read())
    task_type = input_data.get('task_type', '')

    # Obtener recomendaciones
    result = get_recommendations(task_type)

    # Escribir resultado a stdout
    print(json.dumps(result))
