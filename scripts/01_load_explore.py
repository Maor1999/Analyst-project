import pandas as pd

df = pd.read_excel("data/telco_churn.xlsx")
print(df.shape)       
print(df.info())      
print(df.head())        
print(df.isnull().sum())  

print(df[df.isnull().any(axis=1)])

# 1. Drop the junk row (7044) - a real customer always has a Churn value
df = df.dropna(subset=['Churn'])

# 2. Check: do the 11 rows with missing TotalCharges all have tenure=0?
print(df[df['TotalCharges'].isnull()][['tenure', 'MonthlyCharges', 'TotalCharges']])
df['TotalCharges'] = df['TotalCharges'].fillna(0)