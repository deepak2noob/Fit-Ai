import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score
import joblib

# Load train and test data from YogaIntelliJ repo
train_data = pd.read_csv("train_data.csv")
test_data = pd.read_csv("test_data.csv")

# Separate features & labels
X_train = train_data.drop("class", axis=1)
y_train = train_data["class"]

X_test = test_data.drop("class", axis=1)
y_test = test_data["class"]

# Train model
clf = RandomForestClassifier(n_estimators=100, random_state=42)
clf.fit(X_train, y_train)

# Evaluate
y_pred = clf.predict(X_test)
acc = accuracy_score(y_test, y_pred)
print(f"✅ Training complete! Accuracy: {acc*100:.2f}%")

# Save model
joblib.dump(clf, "yoga_pose_model.pkl")
print("Model saved as yoga_pose_model.pkl")
