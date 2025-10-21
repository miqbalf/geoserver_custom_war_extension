# Enhanced GeoServer Setup for GIS Carbon AI

This directory contains an enhanced GeoServer implementation based on the GeoNode approach, featuring improved SSO integration, extension management, and security configuration.

## 🚀 Features

### Enhanced Authentication & SSO
- **Unified Authentication**: Single sign-on across all services
- **Role-Based Access Control (RBAC)**: Granular permissions for different user types
- **JWT Token Integration**: Secure token-based authentication
- **CORS Support**: Cross-origin resource sharing for web applications

### Extension Management
- **Comprehensive Extensions**: WPS, Monitor, Control Flow, CSS, YSLD, and more
- **SSO Extensions**: AuthKey, CAS, LDAP, OAuth2, SAML, REST Security
- **Performance Extensions**: GWC, Vector Tiles, MBStyle
- **Custom Extensions**: Support for custom JAR files

### Security Features
- **Enhanced Security Filters**: Authentication and role-based filters
- **Service-Level Security**: WMS, WFS, WCS access control
- **User Group Management**: Flexible user and group administration
- **Password Policies**: Configurable password requirements

## 📁 Directory Structure

```
geoserver/
├── Dockerfile                 # Enhanced Dockerfile with SSO support
├── entrypoint.sh             # Enhanced entrypoint with security setup
├── install-extensions.sh     # Comprehensive extension installer
├── docker-compose.yml        # Docker Compose configuration
├── scripts/
│   ├── post-startup.sh       # Post-startup configuration
│   └── setup-sso.sh          # SSO configuration script
├── templates/
│   └── global.xml.j2         # GeoServer global configuration template
└── README.md                 # This file
```

## 🔧 Installation & Setup

### 1. Build the Enhanced GeoServer Image

```bash
# Build the GeoServer image with all extensions
docker-compose -f docker-compose.dev.yml build geoserver
```

### 2. Start GeoServer with Enhanced Configuration

```bash
# Start GeoServer with SSO support
docker-compose -f docker-compose.dev.yml up -d geoserver
```

### 3. Run Enhanced SSO Setup

```bash
# Run the enhanced unified SSO setup
./setup-unified-sso-enhanced.sh
```

## 🔐 Authentication Configuration

### Default Users

| Username | Password | Roles |
|----------|----------|-------|
| admin | admin | ROLE_ADMINISTRATOR |
| demo_user | demo123 | ROLE_AUTHENTICATED |
| analyst | analyst123 | ROLE_ANALYST |
| layer_admin | layer123 | ROLE_LAYER_ADMIN |

### Role Hierarchy

- **ROLE_ADMINISTRATOR**: Full system access
- **ROLE_GROUP_ADMIN**: User group management
- **ROLE_SERVICE_ADMIN**: Service configuration
- **ROLE_LAYER_ADMIN**: Layer management
- **ROLE_STYLE_ADMIN**: Style management
- **ROLE_WORKSPACE_ADMIN**: Workspace management
- **ROLE_ANALYST**: Data analysis capabilities
- **ROLE_AUTHENTICATED**: Basic authenticated access
- **ROLE_ANONYMOUS**: Public access

## 🌐 API Endpoints

### GeoServer REST API
- **Base URL**: `http://localhost:8080/geoserver/rest/`
- **Authentication**: Basic Auth or JWT tokens
- **Documentation**: [GeoServer REST API](https://docs.geoserver.org/latest/en/user/rest/)

### Key Endpoints
- `GET /rest/workspaces.json` - List workspaces
- `GET /rest/layers.json` - List layers
- `GET /rest/styles.json` - List styles
- `POST /rest/workspaces` - Create workspace
- `POST /rest/workspaces/{workspace}/datastores` - Create datastore

## 🔧 Configuration

### Environment Variables

```bash
# GeoServer Configuration
GEOSERVER_VERSION=2.26.0
GEOSERVER_DATA_DIR=/geoserver_data/data
GEOSERVER_ADMIN_USER=admin
GEOSERVER_ADMIN_PASSWORD=admin

# CORS Configuration
GEOSERVER_CORS_ENABLED=True
GEOSERVER_CORS_ALLOWED_ORIGINS=*
GEOSERVER_CORS_ALLOWED_METHODS=GET,POST,PUT,DELETE,HEAD,OPTIONS
GEOSERVER_CORS_ALLOWED_HEADERS=*

# SSO Configuration
GEOSERVER_ROLE_SERVICE=default
GEOSERVER_USER_GROUP_SERVICE=default
```

### Custom Configuration

1. **Global Settings**: Edit `templates/global.xml.j2`
2. **Security**: Modify `scripts/setup-sso.sh`
3. **Extensions**: Update `install-extensions.sh`

## 🧪 Testing

### Test GeoServer Access

```bash
# Test basic access
curl -I http://localhost:8080/geoserver/web/

# Test authentication
curl -u admin:admin http://localhost:8080/geoserver/rest/workspaces.json

# Test CORS
curl -H "Origin: http://localhost:8082" \
     -H "Access-Control-Request-Method: GET" \
     -H "Access-Control-Request-Headers: X-Requested-With" \
     -X OPTIONS \
     http://localhost:8080/geoserver/rest/workspaces.json
```

### Test SSO Integration

```bash
# Test Django authentication
curl -X POST http://localhost:8000/api/auth/unified-login/ \
  -H "Content-Type: application/json" \
  -d '{"username": "demo_user", "password": "demo123"}'

# Test GeoServer with JWT token
curl -H "Authorization: Bearer <JWT_TOKEN>" \
     http://localhost:8080/geoserver/rest/workspaces.json
```

## 🚀 Advanced Features

### Custom Extensions

1. Create a `custom-extensions` directory
2. Place your `.jar` files in the directory
3. Rebuild the Docker image

```bash
mkdir -p geoserver/custom-extensions
cp your-extension.jar geoserver/custom-extensions/
docker-compose -f docker-compose.dev.yml build geoserver
```

### Performance Tuning

The Dockerfile includes optimized Java settings:
- **Memory**: 512MB initial, 2GB maximum
- **GC**: Concurrent Mark Sweep
- **Threading**: 4 parallel GC threads
- **Rendering**: Marlin rendering engine

### Monitoring

- **Health Check**: Built-in Docker health check
- **Logging**: JVM logs in `/var/log/jvm.log`
- **Metrics**: Available via JMX (if enabled)

## 🔍 Troubleshooting

### Common Issues

1. **GeoServer not starting**
   ```bash
   # Check logs
   docker-compose -f docker-compose.dev.yml logs geoserver
   
   # Check data directory permissions
   docker exec gis_geoserver_dev ls -la /geoserver_data/data
   ```

2. **Authentication failures**
   ```bash
   # Check user configuration
   docker exec gis_geoserver_dev cat /geoserver_data/data/security/usergroup/default/users.xml
   
   # Restart with fresh configuration
   docker-compose -f docker-compose.dev.yml restart geoserver
   ```

3. **CORS issues**
   ```bash
   # Verify CORS configuration
   curl -H "Origin: http://localhost:8082" \
        -H "Access-Control-Request-Method: GET" \
        -X OPTIONS \
        http://localhost:8080/geoserver/rest/workspaces.json
   ```

### Debug Mode

Enable debug logging by setting:
```bash
export GEOSERVER_LOG_LEVEL=DEBUG
```

## 📚 References

- [GeoServer Documentation](https://docs.geoserver.org/)
- [GeoNode Docker Implementation](https://github.com/GeoNode/geonode-docker)
- [GeoServer REST API](https://docs.geoserver.org/latest/en/user/rest/)
- [GeoServer Security](https://docs.geoserver.org/latest/en/user/security/)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](../LICENSE) file for details.