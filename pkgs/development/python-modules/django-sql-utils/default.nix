{ lib
, buildPythonPackage
, fetchFromGitHub
, hatchling
, django
, sqlparse
}:

buildPythonPackage rec {
  pname = "django-sql-utils";
  version = "0.7.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "martsberger";
    repo = "django-sql-utils";
    rev = version;
    hash = "sha256-OjKPxoWYheu8UQ14KvyiQyHISAQjJep+N4HRc4Msa1w=";
  };

  build-system = [
    hatchling
  ];

  dependencies = [
    django
    sqlparse
  ];

  pythonImportsCheck = [ "django_sql_utils" ];

  meta = {
    description = "SQL utilities for Django";
    homepage = "https://github.com/martsberger/django-sql-utils";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ soyouzpanda ];
  };
}
