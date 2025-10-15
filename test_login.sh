#!/bin/bash
ssh lee@10.0.20.11 "docker exec suporte-api curl -X POST \"http://localhost:8001/api/v1/auth/login\" -H \"Content-Type: application/x-www-form-urlencoded\" -d \"username=admin@empresa.com&password=admin123\""

