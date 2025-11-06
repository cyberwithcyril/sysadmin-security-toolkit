#!/usr/bin/env python3
"""
Test User Data Generator
Generates realistic user data for system administration automation testing
Author: Cyril Thomas
"""

from faker import Faker
import csv
import random
import argparse

# Initialize 
fake = Faker()
Faker.seed(42)  

# Sample Company 
DEPARTMENTS = ['IT', 'Sales', 'Marketing', 'Finance', 'HR', 'Operations', 'Legal']

GROUPS = {
    'IT': ['developers', 'sysadmins', 'devops', 'support'],
    'Sales': ['sales', 'account_managers', 'business_dev'],
    'Marketing': ['marketing', 'content', 'social_media'],
    'Finance': ['finance', 'accounting', 'analysts'],
    'HR': ['hr', 'recruiters', 'training'],
    'Operations': ['operations', 'logistics', 'facilities'],
    'Legal': ['legal', 'compliance']
}

def generate_username(full_name):
    """
    Generate username from full name
    Format: first_initial + last_name (e.g., John Smith -> jsmith)
    """
    parts = full_name.lower().split()
    if len(parts) >= 2:
        username = parts[0][0] + parts[-1]
    else:
        username = parts[0]
    
    # Remove special characters
    username = username.replace("'", "").replace("-", "")
    return username

def generate_email(username, domain="techcorp.com"):
    """Generate corporate email address"""
    return f"{username}@{domain}"

def select_groups(department):
    """Select 1-2 appropriate groups for the department"""
    available_groups = GROUPS[department]
    num_groups = random.randint(1, min(2, len(available_groups)))
    selected = random.sample(available_groups, num_groups)
    return ';'.join(sorted(selected))

def generate_expiry_date():
    """Generate account expiration date (6-24 months in future)"""
    expiry = fake.date_between(start_date='+6m', end_date='+2y')
    return expiry.strftime('%Y-%m-%d')

def generate_users(count, output_file='test_users.csv'):
    """
    Generate realistic test user data
    
    Args:
        count: Number of users to generate
        output_file: CSV filename for output
    """
    print(f"🚀 Generating {count} test users...")
    
    # Track usernames to avoid duplicates
    usernames_used = set()
    users_generated = 0
    
    with open(output_file, 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(['username', 'fullname', 'email', 'department', 'groups', 'account_expiry'])
        
        while users_generated < count:
            # Generate user data
            full_name = fake.name()
            username = generate_username(full_name)
            
            # Handle duplicate usernames
            if username in usernames_used:
                suffix = 2
                while f"{username}{suffix}" in usernames_used:
                    suffix += 1
                username = f"{username}{suffix}"
            
            usernames_used.add(username)
            
            # Generate other fields
            department = random.choice(DEPARTMENTS)
            groups = select_groups(department)
            email = generate_email(username)
            expiry = generate_expiry_date()
            
            # Write to CSV
            writer.writerow([username, full_name, email, department, groups, expiry])
            users_generated += 1
            
            # Progress indicator
            if users_generated % 10 == 0:
                print(f"  ✓ Generated {users_generated}/{count} users...")
    
    print(f"\n✅ Successfully generated {count} users in {output_file}")
    
    # Show sample
    print(f"\n📋 Sample of generated data:")
    with open(output_file, 'r') as f:
        for i, line in enumerate(f):
            print(f"  {line.rstrip()}")
            if i >= 3:  # Show first 4 lines (header + 3 users)
                break

def main():
    parser = argparse.ArgumentParser(
        description='Generate realistic test user data for system administration testing'
    )
    parser.add_argument(
        '--count', '-c',
        type=int,
        default=50,
        help='Number of users to generate (default: 50)'
    )
    parser.add_argument(
        '--output', '-o',
        default='../input/test_users.csv',
        help='Output CSV filename (default: ../input/test_users.csv)'
    )
    
    args = parser.parse_args()
    
    generate_users(count=args.count, output_file=args.output)

if __name__ == '__main__':
    main()
