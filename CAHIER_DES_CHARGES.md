# Cahier des Charges - Plateforme d'Urgences Médicales
## Document Technique Complet 2025-2026

---

## 1. CONTEXTE & OBJECTIFS

### 1.1 Vision
Plateforme cloud-native intégrant IA, géolocalisation temps réel et orchestration d'urgences médicales pour hôpitaux et centres de dispatch.

### 1.2 Objectifs Principaux
- Réduction temps de réponse ambulances: 12min → 7min (-40%)
- Optimisation ressources médicales: +35% efficacité
- Intégration IA diagnostique temps réel
- Scalabilité: 10K+ requêtes/sec
- Disponibilité: 99.95% SLA

---

## 2. ARCHITECTURE TECHNIQUE

### 2.1 Stack Technologique

#### Backend (Node.js 24.x LTS)
```
Framework: Express.js / Hono
Runtime: Node.js 22.x → 24.x LTS (2026)
Database: PostgreSQL + Supabase
Cache: Redis
Message Queue: Bull/RabbitMQ
```

#### Frontend
- **Web**: React 19 + Vite 6 + TypeScript 5.8
- **Mobile**: React Native / Flutter
- **iOS Natif**: SwiftUI (LBox integration)

#### Infrastructure
- **Cloud**: AWS / GCP / Azure
- **Kubernetes**: EKS/GKE
- **CDN**: CloudFlare / AWS CloudFront
- **Monitoring**: DataDog / New Relic

### 2.2 Microservices Architecture

```
┌─────────────────────────────────────────┐
│         API Gateway (Kong/Nginx+)       │
├─────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────────┐ │
│  │  Auth Svc    │  │ Dispatch Engine  │ │
│  └──────────────┘  └──────────────────┘ │
├─────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────────┐ │
│  │  Location    │  │  AI Diagnostics  │ │
│  │  Service     │  │  Service         │ │
│  └──────────────┘  └──────────────────┘ │
├─────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────────┐ │
│  │  Notification│  │  Analytics       │ │
│  │  Service     │  │  Service         │ │
│  └──────────────┘  └──────────────────┘ │
└─────────────────────────────────────────┘
           ↓
    ┌─────────────────┐
    │ PostgreSQL      │
    │ Supabase        │
    └─────────────────┘
```

---

## 3. MODULES CORE

### 3.1 Module d'Authentification & Autorisation

**Features**:
- OAuth2 + JWT
- MFA (TOTP, SMS, Email)
- RBAC (Role-Based Access Control)
- SSO Enterprise
- Audit logging complet

**Sécurité**:
- TLS 1.3 mandatory
- Rate limiting: 100 req/sec par IP
- CSRF protection
- CORS strict

### 3.2 Module Géolocalisation Temps Réel

**Features**:
- GPS + WiFi triangulation
- Real-time tracking ambulances
- Heat maps densité appels
- Prediction routière (Google Maps API)
- Offline-first capability

**Performance**:
- Latence: < 200ms
- Update frequency: 5s
- WebSocket + gRPC

### 3.3 Module IA Diagnostique

**ML Models**:
- Classification urgence (triage IA)
- Symptom matching (NLP)
- Prediction complications
- Resource allocation (optimization)

**Stack ML**:
- TensorFlow Lite (mobile)
- FastAPI (Python backend)
- Model versioning: MLflow
- A/B testing: Continuous deployment

### 3.4 Module Dispatch & Routing

**Algorithmes**:
- TSP (Traveling Salesman Problem)
- Hungarian algorithm (ressource matching)
- A* pathfinding
- Load balancing ambulances

**Constraints**:
- Priorités médicales
- Capacités ambulances
- Zones couverture
- Temps réaction < 90s

### 3.5 Module Notifications

**Canaux**:
- Push notifications (FCM, APNs)
- SMS (Twilio)
- In-app real-time (WebSocket)
- Email (SendGrid)

**Latence garantie**: < 2s pour critiques

---

## 4. BASE DE DONNÉES

### 4.1 Schema Principal

```sql
-- Utilisateurs
CREATE TABLE users (
  id UUID PRIMARY KEY,
  email VARCHAR UNIQUE,
  phone VARCHAR,
  role ENUM('admin', 'medecin', 'ambulancier', 'superviseur'),
  status ENUM('active', 'inactive', 'suspended'),
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);

-- Appels d'urgence
CREATE TABLE emergency_calls (
  id UUID PRIMARY KEY,
  caller_id UUID REFERENCES users,
  latitude DECIMAL,
  longitude DECIMAL,
  severity ENUM('critical', 'urgent', 'normal', 'low'),
  symptoms JSONB,
  ai_triage_score FLOAT,
  assigned_ambulance_id UUID,
  status ENUM('received', 'processing', 'dispatched', 'en_route', 'arrived', 'closed'),
  created_at TIMESTAMP,
  responded_at TIMESTAMP,
  arrived_at TIMESTAMP
);

-- Ambulances
CREATE TABLE ambulances (
  id UUID PRIMARY KEY,
  code VARCHAR UNIQUE,
  latitude DECIMAL,
  longitude DECIMAL,
  status ENUM('available', 'en_route', 'on_scene', 'transporting', 'at_hospital'),
  crew_ids UUID[],
  capacity INT,
  equipment JSONB,
  updated_at TIMESTAMP
);

-- Analytics
CREATE TABLE call_analytics (
  id UUID PRIMARY KEY,
  call_id UUID REFERENCES emergency_calls,
  response_time_ms INT,
  dispatch_time_ms INT,
  travel_time_ms INT,
  outcome VARCHAR,
  patient_outcome VARCHAR,
  created_at TIMESTAMP
);
```

### 4.2 Indexation Performance

```sql
CREATE INDEX idx_calls_status ON emergency_calls(status);
CREATE INDEX idx_calls_created ON emergency_calls(created_at DESC);
CREATE INDEX idx_calls_location ON emergency_calls USING gist(
  ll_to_earth(latitude, longitude)
);
CREATE INDEX idx_ambulances_location ON ambulances USING gist(
  ll_to_earth(latitude, longitude)
);
CREATE INDEX idx_ambulances_status ON ambulances(status);
```

### 4.3 Row-Level Security (RLS)

```sql
-- Médecins peuvent voir appels de leur zone
CREATE POLICY medecin_view_calls ON emergency_calls
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid()
      AND users.role = 'medecin'
      AND users.zone = calls.zone
    )
  );

-- Ambulanciers voient appels assignés
CREATE POLICY ambulancier_view_assignment ON emergency_calls
  FOR SELECT
  USING (
    assigned_ambulance_id IN (
      SELECT id FROM ambulances
      WHERE auth.uid() = ANY(crew_ids)
    )
  );
```

---

## 5. APIs & ENDPOINTS

### 5.1 REST Endpoints

```
POST   /api/v1/emergency-calls         [Create call]
GET    /api/v1/emergency-calls/{id}    [Get call details]
PATCH  /api/v1/emergency-calls/{id}    [Update status]

POST   /api/v1/ambulances/location     [Update location]
GET    /api/v1/ambulances/available    [List available]

POST   /api/v1/auth/register           [Register user]
POST   /api/v1/auth/login              [Login]
POST   /api/v1/auth/refresh-token      [Refresh JWT]

GET    /api/v1/analytics/response-time [Analytics]
```

### 5.2 WebSocket Events

```javascript
// Real-time ambulance tracking
ws.on('ambulance_location_update', (data) => {
  // latitude, longitude, status, timestamp
});

// Call status updates
ws.on('call_status_changed', (data) => {
  // call_id, new_status, ambulance_id
});

// Notifications
ws.on('notification', (data) => {
  // message, priority, type
});
```

---

## 6. SÉCURITÉ & COMPLIANCE

### 6.1 Standards Appliqués

✅ **HIPAA** (Health Insurance Portability)
✅ **GDPR** (General Data Protection Regulation)
✅ **RGPD** (Réglement Général Protection Données)
✅ **CCPA** (California Consumer Privacy Act)
✅ **SOC 2 Type II**
✅ **ISO 27001** (Information Security)

### 6.2 Mesures de Sécurité

- **Encryption**: AES-256 at-rest, TLS 1.3 in-transit
- **Audit Logging**: 7 ans de conservation (HIPAA requirement)
- **Zero-trust Architecture**: Verification tous les appels
- **Secrets Management**: HashiCorp Vault
- **DLP (Data Loss Prevention)**: Automated scanning

### 6.3 Pentest & Compliance

- Pentest externe: Annuellement
- Code security scanning: SonarQube + Snyk
- OWASP Top 10 hardening
- PII masking in logs

---

## 7. PERFORMANCE & SCALABILITÉ

### 7.1 SLA Requirements

```
Availability:          99.95% (4h downtime/an)
Response Time (p95):   < 500ms
Response Time (p99):   < 1s
Throughput:            10,000 req/sec
Concurrency:           50,000 connections
Database:              < 100ms queries (p95)
```

### 7.2 Load Testing

- **Tool**: k6 + Apache JMeter
- **Target**: 10K concurrent users
- **Ramp-up**: 5min
- **Duration**: 30min
- **Acceptance**: Pass if p95 < 500ms

### 7.3 Caching Strategy

```javascript
// CDN (CloudFlare): Static assets, 24h TTL
// Redis (L1): Session data, API responses, 5min TTL
// Browser: Assets versioned (cache busting)
// Database Query Cache: 2min for analytics
```

### 7.4 Auto-scaling

```yaml
HPA (Horizontal Pod Autoscaler):
  min_replicas: 3
  max_replicas: 50
  target_cpu: 70%
  target_memory: 80%
```

---

## 8. MONITORING & OBSERVABILITY

### 8.1 Metrics Collectés

```
Application:
  - Request latency
  - Error rates (5xx, 4xx)
  - Throughput (requests/sec)
  - Active connections

Business:
  - Average response time (ambulance)
  - Call completion rate
  - Patient satisfaction (CSAT)
  - System availability %

Infrastructure:
  - CPU utilization
  - Memory usage
  - Disk I/O
  - Network bandwidth
```

### 8.2 Logging

```
Centralized Logging: ELK Stack / DataDog
Log Levels:
  - ERROR: System failures, exceptions
  - WARNING: Degraded performance, retries
  - INFO: API calls, state changes
  - DEBUG: Detailed execution traces

Retention:
  - DEBUG logs: 7 days
  - ERROR logs: 1 year
  - Audit logs: 7 years
```

### 8.3 Alerting

```yaml
Critical:
  - API error rate > 5%
  - Response time p95 > 2s
  - Database down
  - Ambulance geo-service down

High:
  - Memory usage > 85%
  - Database query > 500ms
  - Queue depth > 1000

Escalation:
  - Page on-call engineer
  - Slack #incidents
  - Email ops team
```

---

## 9. DÉPLOIEMENT & CI/CD

### 9.1 Pipeline CI/CD

```
Push → Test → Build → SonarQube → Deploy Staging → Deploy Prod
         ↓       ↓        ↓             ↓              ↓
       Jest    Docker   Security      E2E           Blue-Green
       ESLint  Registry  Scan         Tests         Deployment
```

### 9.2 Infrastructure as Code (IaC)

```
Terraform/CloudFormation:
  - VPC, Subnets, Security Groups
  - RDS PostgreSQL (Multi-AZ)
  - Kubernetes (EKS/GKE)
  - Lambda functions
  - API Gateway

Helm Charts:
  - App deployment
  - Redis, Postgres sidecars
  - Monitoring stack
```

### 9.3 Version Strategy

```
Semantic Versioning: MAJOR.MINOR.PATCH
  - MAJOR: Breaking changes
  - MINOR: New features (backwards-compatible)
  - PATCH: Bug fixes

Release Tags:
  - v1.0.0 (production)
  - v1.0.0-rc1 (release candidate)
  - v1.0.0-beta1 (beta testing)
```

---

## 10. ROADMAP 2025-2026

### Phase 1: MVP (Mois 1-3)
- Core emergency call intake
- Basic dispatch algorithm
- User authentication
- Mobile app (iOS)

### Phase 2: Enhancement (Mois 4-6)
- Real-time ambulance tracking
- AI triage engine
- Advanced routing
- Analytics dashboard

### Phase 3: AI & Intelligence (Mois 7-9)
- ML-based resource prediction
- Pattern recognition (call trends)
- Multi-language support (AI)
- Integration external hospital systems

### Phase 4: Enterprise (Mois 10-12)
- SSO / Active Directory
- Advanced compliance reporting
- API for 3rd-party integrations
- Global expansion support

---

## 11. COÛTS & ROI

### 11.1 Budget Année 1

```
Development:           $200K
Infrastructure:        $80K
3rd-party services:    $50K
Licensing/tools:       $30K
Operations/support:    $40K
────────────────────────────
TOTAL:                $400K
```

### 11.2 Savings Estimés

```
Operational Efficiency:     $500K/year
Reduced Incidents:          $300K/year
Faster Response Times:      $400K/year
────────────────────────────
TOTAL SAVINGS:            $1.2M/year

ROI Year 1: (1.2M - 0.4M) / 0.4M = 200%
Payback Period: 4 months
```

---

## 12. RISQUES & MITIGATION

| Risque | Probabilité | Impact | Mitigation |
|--------|-------------|--------|-----------|
| Latency dans dispatch | Moyenne | Critique | Load testing, caching, CDN |
| Data breach HIPAA | Faible | Critique | Encryption, access control, audit |
| Ambulance GPS failure | Moyenne | Haute | Fallback manual location, 4G/LTE dual |
| AI model bias | Faible | Haute | Fairness testing, human override |
| Vendor lock-in | Faible | Moyenne | Multi-cloud strategy, open APIs |

---

## 13. CONCLUSION

Plateforme conçue pour être:
- **Secure**: HIPAA/GDPR compliant
- **Scalable**: 10K+ req/sec capacity
- **Reliable**: 99.95% uptime SLA
- **Intelligent**: AI-powered dispatch
- **User-centric**: Mobile-first design

**Recommendation**: GO-LIVE Phase 1 Q2 2025