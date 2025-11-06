#!/usr/bin/env python3
"""
Script Name: generate_users.py
Description: Generate realistic test user data using Faker
Author: Cyril Thomas
Date: October 21, 2025
Version: 1.0
"""

from faker import Faker
import csv
import random
from datetime import datetime

# Initialize 
fake = Faker()

# Configuration
NUM_USERS = 50
OUTPUT_FILE = 'test_users.csv'

# Possible departments and roles
DEPARTMENTS = ['Engineering', 'Sales', 'Marketing', 'HR', 'Finance', 'Operations', 'IT', 'Support']
ROLES = ['Developer', 'Manager', 'Analyst', 'Engineer', 'Specialist', 'Coordinator', 'Director']

def generate_username(first_name, last_name):
    """Generate username from first and last name"""
    formats = [
        f"{first_name.lower()}{last_name.lower()}",
        f"{first_name.lower()}.{last_name.lower()}",
        f"{first_name[0].lower()}{last_name.lower()}"
    ]
    return random.choice(formats)

def generate_user():
    """Generate a single user's data"""
    first_name = fake.first_name()
    last_name = fake.last_name()
    username = generate_username(first_name, last_name)
    
    return {
        'username': username,
        'first_name': first_name,
        'last_name': last_name,
        'full_name': f"{first_name} {last_name}",
        'email': fake.company_email(),
        'phone': fake.phone_number(),
        'department': random.choice(DEPARTMENTS),
        'role': random.choice(ROLES),
        'start_date': fake.date_between(start_date='-2y', end_date='today'),
        'employee_id': fake.unique.random_number(digits=6)
    }

def main():
    """Generate user data and save to CSV"""
    print("=" * 60)
    print(" User Data Generator")
    print("=" * 60)
    print(f"\nGenerating {NUM_USERS} test users...")
    
    users = []
    for i in range(NUM_USERS):
        user = generate_user()
        users.append(user)
        if (i + 1) % 10 == 0:
            print(f"  Generated {i + 1}/{NUM_USERS} users...")
    
    print(f"\nWriting data to {OUTPUT_FILE}...")
    with open(OUTPUT_FILE, 'w', newline='', encoding='utf-8') as csvfile:
        fieldnames = ['username', 'first_name', 'last_name', 'full_name', 
                      'email', 'phone', 'department', 'role', 'start_date', 'employee_id']
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        
        writer.writeheader()
        for user in users:
            writer.writerow(user)
    
    print(f"✓ Successfully generated {NUM_USERS} users!")
    print(f"✓ Data saved to: {OUTPUT_FILE}")
    print("\nSample users:")
    print("-" * 60)
    for user in users[:5]:
        print(f"  {user['username']:20s} | {user['full_name']:20s} | {user['department']}")
    
    print("\n" + "=" * 60)
    print("Data generation complete!")
    print("=" * 60)

if __name__ == '__main__':
    main()
