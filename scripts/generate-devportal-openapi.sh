#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 --env-file <devportal.env> --output <openapi.yaml> [--report <report.md>] [--include-prod-routes]"
}

ENV_FILE="kong/env/user/devportal.env"
OUTPUT_SPEC="Internal Dev Portal.yaml"
REPORT_FILE="devportal-openapi-report.md"
INCLUDE_PROD_ROUTES="false"
OPENAPI_VERSION=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --env-file)
      ENV_FILE="${2:-}"
      shift 2
      ;;
    --output)
      OUTPUT_SPEC="${2:-}"
      shift 2
      ;;
    --report)
      REPORT_FILE="${2:-}"
      shift 2
      ;;
    --include-prod-routes)
      INCLUDE_PROD_ROUTES="true"
      shift
      ;;
    --version)
      OPENAPI_VERSION="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1"
      usage
      exit 1
      ;;
  esac
done

case "$ENV_FILE" in
  */devportal.env|devportal.env) ;;
  *)
    echo "Refusing to read non-devportal env file: $ENV_FILE"
    exit 1
    ;;
esac

test -f "$ENV_FILE" || { echo "Dev Portal env file not found: $ENV_FILE"; exit 1; }
test -d "kong/internal/onprem/routes" || { echo "Route directory not found: kong/internal/onprem/routes"; exit 1; }
test -d "kong/internal/onprem/services" || { echo "Service directory not found: kong/internal/onprem/services"; exit 1; }

ENV_FILE="$ENV_FILE" \
OUTPUT_SPEC="$OUTPUT_SPEC" \
REPORT_FILE="$REPORT_FILE" \
INCLUDE_PROD_ROUTES="$INCLUDE_PROD_ROUTES" \
OPENAPI_VERSION="$OPENAPI_VERSION" \
perl <<'PERL'
use strict;
use warnings;

my $env_file = $ENV{ENV_FILE};
my $output_spec = $ENV{OUTPUT_SPEC};
my $report_file = $ENV{REPORT_FILE};
my $include_prod_routes = $ENV{INCLUDE_PROD_ROUTES} eq 'true';
my $explicit_version = $ENV{OPENAPI_VERSION} || '';

sub read_file {
  my ($path) = @_;
  open my $fh, '<', $path or die "Cannot read $path: $!";
  local $/;
  return <$fh>;
}

sub write_file {
  my ($path, $content) = @_;
  open my $fh, '>', $path or die "Cannot write $path: $!";
  print {$fh} $content;
}

sub parse_env {
  my ($path) = @_;
  open my $fh, '<', $path or die "Cannot read $path: $!";
  my %env;
  while (defined(my $line = <$fh>)) {
    chomp $line;
    $line =~ s/\r$//;
    next if $line =~ /^\s*$/ || $line =~ /^\s*#/;

    if ($line =~ /^([A-Za-z_][A-Za-z0-9_]*)<<([A-Za-z0-9_]+)$/) {
      my ($key, $marker) = ($1, $2);
      my @body;
      while (defined(my $body_line = <$fh>)) {
        chomp $body_line;
        $body_line =~ s/\r$//;
        last if $body_line eq $marker;
        push @body, $body_line;
      }
      $env{$key} = join("\n", @body);
      next;
    }

    next unless $line =~ /^([A-Za-z_][A-Za-z0-9_]*)=(.*)$/;
    my ($key, $value) = ($1, $2);
    $value =~ s/^"(.*)"$/$1/;
    $value =~ s/^'(.*)'$/$1/;
    $env{$key} = $value;
  }
  close $fh;
  return %env;
}

sub key_for {
  my ($prefix, $method, $path) = @_;
  my $suffix = uc($path);
  $suffix =~ s/[^A-Z0-9]+/_/g;
  $suffix =~ s/^_+|_+$//g;
  return "${prefix}_" . uc($method) . "_$suffix";
}

sub yaml_quote {
  my ($value) = @_;
  $value = '' unless defined $value;
  $value =~ s/\\/\\\\/g;
  $value =~ s/"/\\"/g;
  return qq{"$value"};
}

sub yaml_block {
  my ($indent, $value) = @_;
  my $pad = ' ' x $indent;
  return join("\n", map { $pad . $_ } split /\n/, $value, -1);
}

sub titleize {
  my ($value) = @_;
  $value =~ s/[-_]+/ /g;
  $value =~ s/\b(\w)/uc($1)/ge;
  return $value;
}

sub read_version {
  my ($path) = @_;
  return '1.0.0' unless -f $path;
  my $content = read_file($path);
  return $1 if $content =~ /^\s*version:\s*"?([0-9]+(?:\.[0-9]+){0,2})"?\s*$/m;
  return '1.0.0';
}

sub increment_patch {
  my ($version) = @_;
  my @parts = split /\./, $version;
  push @parts, 0 while @parts < 3;
  $parts[2]++;
  return join '.', @parts[0..2];
}

sub extract_list {
  my ($block, $field) = @_;
  return () unless $block =~ /^    "$field":\s*\n((?:^      - .+\n?)+)/m;
  my $items = $1;
  my @values;
  while ($items =~ /^      - "?([^"\n]+)"?/mg) {
    push @values, $1;
  }
  return @values;
}

sub extract_service_oidc {
  my %service_has_oidc;
  for my $file (sort glob "kong/internal/onprem/services/*.yaml") {
    my $content = read_file($file);
    my @blocks = split /^  - "connect_timeout":/m, $content;
    shift @blocks if @blocks && $blocks[0] !~ /"name":/;
    for my $block (@blocks) {
      next unless $block =~ /^    "name": "([^"]+)"/m;
      my $service = $1;
      $service_has_oidc{$service} = 1 if $block =~ /"name": "openid-connect"/;
    }
  }
  return %service_has_oidc;
}

sub extract_routes {
  my @routes;
  for my $file (sort glob "kong/internal/onprem/routes/*.yaml") {
    next if !$include_prod_routes && $file =~ /-prod\.yaml$/;
    my $content = read_file($file);
    my @blocks = split /^  - "hosts":/m, $content;
    shift @blocks if @blocks && $blocks[0] !~ /"name":/;
    for my $block (@blocks) {
      next unless $block =~ /^    "name": "([^"]+)"/m;
      my $route_name = $1;
      next unless $block =~ /^    "service":\s*\n^      "name": "([^"]+)"/m;
      my $service_name = $1;
      my @paths = extract_list($block, 'paths');
      my @methods = grep { $_ ne 'OPTIONS' } extract_list($block, 'methods');
      my @tags = grep { $_ !~ /^route:/ } extract_list($block, 'tags');
      my $tag = $tags[0] || $service_name;
      next unless @paths && @methods;
      push @routes, {
        file => $file,
        name => $route_name,
        service => $service_name,
        tag => $tag,
        paths => \@paths,
        methods => \@methods,
        route_has_oidc => ($block =~ /"name": "openid-connect"/ ? 1 : 0),
        plugins => [map { $1 } ($block =~ /"name": "([^"]+)"/g)],
      };
    }
  }
  return @routes;
}

my %env = parse_env($env_file);
my %service_has_oidc = extract_service_oidc();
my @routes = extract_routes();
my $version = $explicit_version ne '' ? $explicit_version : increment_patch(read_version($output_spec));

my %tag_seen;
my @tags;
for my $route (@routes) {
  next if $tag_seen{$route->{tag}}++;
  push @tags, $route->{tag};
}

my %header_components;
my @operations;

for my $route (@routes) {
  for my $path (@{$route->{paths}}) {
    for my $method (@{$route->{methods}}) {
      my $method_lower = lc $method;
      my $op_key = key_for('DP', $method, $path);
      my $body_key = key_for('DP_REQUEST_BODY', $method, $path);
      my $content_type_key = key_for('DP_CONTENT_TYPE', $method, $path);
      my $headers_key = key_for('DP_EXTRA_HEADERS', $method, $path);
      my $query_key = key_for('DP_QUERY_PARAMS', $method, $path);
      my $requires_bearer = ($route->{route_has_oidc} || $service_has_oidc{$route->{service}}) ? 1 : 0;
      my @extra_headers = grep { $_ ne '' } map { s/^\s+|\s+$//gr } split /,/, ($env{$headers_key} // '');
      $header_components{$_} = 1 for @extra_headers;
      push @operations, {
        path => $path,
        method => $method_lower,
        route => $route,
        op_key => $op_key,
        body_key => $body_key,
        content_type => $env{$content_type_key} || 'application/json',
        body => $env{$body_key} // '',
        requires_bearer => $requires_bearer,
        extra_headers => \@extra_headers,
        query_params => $env{$query_key} || '',
      };
    }
  }
}

@operations = sort {
  $a->{route}->{tag} cmp $b->{route}->{tag}
    || $a->{path} cmp $b->{path}
    || $a->{method} cmp $b->{method}
} @operations;

sub header_component_name {
  my ($header) = @_;
  my $name = $header;
  $name =~ s/[^A-Za-z0-9]+/_/g;
  $name =~ s/^_+|_+$//g;
  return $name . 'Header';
}

my $yaml = '';
$yaml .= "openapi: \"3.0.0\"\n";
$yaml .= "info:\n";
$yaml .= "  title: " . yaml_quote($env{DEVPORTAL_TITLE} || 'Kong Konnect Internal APIs') . "\n";
$yaml .= "  version: " . yaml_quote($version) . "\n";
$yaml .= "  description: " . yaml_quote($env{DEVPORTAL_DESCRIPTION} || 'Generated from Kong Gateway services and routes.') . "\n";
$yaml .= "servers:\n";
$yaml .= "  - url: " . yaml_quote($env{DEVPORTAL_SERVER_URL} || 'https://example.com') . "\n";
$yaml .= "    description: " . yaml_quote($env{DEVPORTAL_SERVER_DESCRIPTION} || 'Kong Gateway server') . "\n";
$yaml .= "tags:\n";
for my $tag (@tags) {
  my $desc = $env{'DP_TAG_DESCRIPTION_' . uc($tag =~ s/[^A-Za-z0-9]+/_/gr)} || "$tag APIs";
  $yaml .= "  - name: " . yaml_quote($tag) . "\n";
  $yaml .= "    description: " . yaml_quote($desc) . "\n";
}
$yaml .= "paths:\n";

for my $op (@operations) {
  $yaml .= "  " . yaml_quote($op->{path}) . ":\n" unless $yaml =~ /\Q  @{[yaml_quote($op->{path})]}:\E\n/s;
  $yaml .= "    $op->{method}:\n";
  $yaml .= "      tags:\n";
  $yaml .= "        - " . yaml_quote($op->{route}->{tag}) . "\n";
  $yaml .= "      summary: " . yaml_quote($env{$op->{op_key} . '_SUMMARY'} || titleize($op->{route}->{name})) . "\n";
  $yaml .= "      description: " . yaml_quote($env{$op->{op_key} . '_DESCRIPTION'} || "Generated from Kong route $op->{route}->{name}, service $op->{route}->{service}.") . "\n";
  $yaml .= "      security: []\n" unless $op->{requires_bearer};

  my @params;
  push @params, { ref => '#/components/parameters/AuthorizationHeader' } if $op->{requires_bearer};
  for my $header (@{$op->{extra_headers}}) {
    push @params, { ref => '#/components/parameters/' . header_component_name($header) };
  }
  for my $raw_param (grep { $_ ne '' } map { s/^\s+|\s+$//gr } split /,/, $op->{query_params}) {
    my $required = $raw_param =~ s/\*$// ? 'true' : 'false';
    push @params, { query => $raw_param, required => $required };
  }

  if (@params) {
    $yaml .= "      parameters:\n";
    for my $param (@params) {
      if ($param->{ref}) {
        $yaml .= "        - \$ref: " . yaml_quote($param->{ref}) . "\n";
      } else {
        $yaml .= "        - name: " . yaml_quote($param->{query}) . "\n";
        $yaml .= "          in: \"query\"\n";
        $yaml .= "          required: $param->{required}\n";
        $yaml .= "          schema:\n";
        $yaml .= "            type: \"string\"\n";
      }
    }
  }

  if ($op->{body} ne '') {
    $yaml .= "      requestBody:\n";
    $yaml .= "        required: true\n";
    $yaml .= "        content:\n";
    $yaml .= "          " . yaml_quote($op->{content_type}) . ":\n";
    $yaml .= "            schema:\n";
    $yaml .= "              type: " . ($op->{content_type} =~ /xml|text/ ? '"string"' : '"object"') . "\n";
    $yaml .= "            example: |\n";
    $yaml .= yaml_block(14, $op->{body}) . "\n";
  }

  $yaml .= "      responses:\n";
  $yaml .= "        \"200\":\n";
  $yaml .= "          description: \"Success\"\n";
}

$yaml .= "components:\n";
$yaml .= "  parameters:\n";
$yaml .= "    AuthorizationHeader:\n";
$yaml .= "      name: \"Authorization\"\n";
$yaml .= "      in: \"header\"\n";
$yaml .= "      required: true\n";
$yaml .= "      description: \"Bearer token required by the OIDC plugin on the owning service or route.\"\n";
$yaml .= "      schema:\n";
$yaml .= "        type: \"string\"\n";
$yaml .= "        example: \"Bearer <access_token>\"\n";
for my $header (sort keys %header_components) {
  my $component = header_component_name($header);
  $yaml .= "    $component:\n";
  $yaml .= "      name: " . yaml_quote($header) . "\n";
  $yaml .= "      in: \"header\"\n";
  $yaml .= "      required: true\n";
  $yaml .= "      description: " . yaml_quote("Additional header configured from $env_file.") . "\n";
  $yaml .= "      schema:\n";
  $yaml .= "        type: \"string\"\n";
  $yaml .= "        example: " . yaml_quote("<$header>") . "\n";
}

write_file($output_spec, $yaml);

my $report = "# Dev Portal OpenAPI Generation Report\n\n";
$report .= "- Source routes: `kong/internal/onprem/routes`\n";
$report .= "- Source services: `kong/internal/onprem/services`\n";
$report .= "- Env metadata: `$env_file`\n";
$report .= "- Output spec: `$output_spec`\n";
$report .= "- Generated version: `$version`\n";
$report .= "- Route operations: `" . scalar(@operations) . "`\n\n";
$report .= "| Method | Path | Tag | Service | Bearer | Extra Headers | Request Body Key |\n";
$report .= "| --- | --- | --- | --- | --- | --- | --- |\n";
for my $op (@operations) {
  my $headers = @{$op->{extra_headers}} ? join(', ', @{$op->{extra_headers}}) : '';
  my $body_state = $op->{body} ne '' ? $op->{body_key} : '';
  $report .= "| " . uc($op->{method}) . " | `$op->{path}` | $op->{route}->{tag} | $op->{route}->{service} | " . ($op->{requires_bearer} ? 'yes' : 'no') . " | $headers | $body_state |\n";
}
write_file($report_file, $report);

print "Generated $output_spec version $version with " . scalar(@operations) . " operations.\n";
print "Generated $report_file.\n";
PERL
