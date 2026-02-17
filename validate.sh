#!/bin/bash
# Validation script for OpenClaw Juju Charm

set -e

echo "🔍 Validating OpenClaw Juju Charm..."
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

passed=0
failed=0

check() {
    if eval "$2"; then
        echo -e "${GREEN}✓${NC} $1"
        passed=$((passed+1))
    else
        echo -e "${RED}✗${NC} $1"
        failed=$((failed+1))
    fi
}

echo "📦 File Structure Checks"
check "metadata.yaml exists" "[ -f metadata.yaml ]"
check "config.yaml exists" "[ -f config.yaml ]"
check "charmcraft.yaml exists" "[ -f charmcraft.yaml ]"
check "README.md exists" "[ -f README.md ]"
check "LICENSE exists" "[ -f LICENSE ]"
check "hooks directory exists" "[ -d hooks ]"
check "docs directory exists" "[ -d docs ]"
check ".github/workflows directory exists" "[ -d .github/workflows ]"

echo ""
echo "🪝 Hook Checks"
check "install hook exists" "[ -f hooks/install ]"
check "start hook exists" "[ -f hooks/start ]"
check "stop hook exists" "[ -f hooks/stop ]"
check "config-changed hook exists" "[ -f hooks/config-changed ]"
check "upgrade-charm hook exists" "[ -f hooks/upgrade-charm ]"
check "common.sh exists" "[ -f hooks/common.sh ]"

check "install hook is executable" "[ -x hooks/install ]"
check "start hook is executable" "[ -x hooks/start ]"
check "stop hook is executable" "[ -x hooks/stop ]"
check "config-changed hook is executable" "[ -x hooks/config-changed ]"
check "upgrade-charm hook is executable" "[ -x hooks/upgrade-charm ]"

check "leader-elected symlink exists" "[ -L hooks/leader-elected ]"
check "leader-settings-changed symlink exists" "[ -L hooks/leader-settings-changed ]"
check "remove symlink exists" "[ -L hooks/remove ]"

echo ""
echo "📄 Metadata Validation"
check "metadata.yaml has name field" "grep -q '^name:' metadata.yaml"
check "metadata.yaml has summary field" "grep -q '^summary:' metadata.yaml"
check "metadata.yaml has description field" "grep -q '^description:' metadata.yaml"
check "metadata.yaml has maintainer field" "grep -q '^maintainer:' metadata.yaml"
check "metadata.yaml has series field" "grep -q '^series:' metadata.yaml"

echo ""
echo "⚙️  Configuration Validation"
check "config.yaml has options field" "grep -q '^options:' config.yaml"
check "config.yaml has gateway-port" "grep -q 'gateway-port:' config.yaml"
check "config.yaml has ai-provider" "grep -q 'ai-provider:' config.yaml"
check "config.yaml has ai-api-key" "grep -q 'ai-api-key:' config.yaml"

echo ""
echo "🔄 Workflow Validation"
check "test.yaml workflow exists" "[ -f .github/workflows/test.yaml ]"
check "publish.yaml workflow exists" "[ -f .github/workflows/publish.yaml ]"
check "pages.yaml workflow exists" "[ -f .github/workflows/pages.yaml ]"

echo ""
echo "📚 Documentation Checks"
check "GitHub Pages index.html exists" "[ -f docs/index.html ]"
check "CONTRIBUTING.md exists" "[ -f CONTRIBUTING.md ]"
check "Bug report template exists" "[ -f .github/ISSUE_TEMPLATE/bug_report.md ]"
check "Feature request template exists" "[ -f .github/ISSUE_TEMPLATE/feature_request.md ]"
check "PR template exists" "[ -f .github/pull_request_template.md ]"

echo ""
echo "🔧 Shell Script Validation"
if command -v shellcheck &> /dev/null; then
    if shellcheck hooks/install hooks/start hooks/stop hooks/config-changed hooks/upgrade-charm hooks/common.sh > /dev/null; then
        echo -e "${GREEN}✓${NC} All hooks pass shellcheck"
        passed=$((passed+1))
    else
        echo -e "${RED}✗${NC} Shellcheck found issues in hooks"
        failed=$((failed+1))
        shellcheck hooks/* 2>&1 | head -20
    fi
else
    echo "⚠️  shellcheck not installed, skipping shell validation"
fi

echo ""
echo "📊 Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "Passed: ${GREEN}${passed}${NC}"
echo -e "Failed: ${RED}${failed}${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ $failed -eq 0 ]; then
    echo ""
    echo "🎉 All validations passed! Charm is ready."
    echo ""
    echo "Next steps:"
    echo "1. Initialize git repository: git init && git add . && git commit -m 'Initial commit'"
    echo "2. Pack charm: charmcraft pack"
    echo "3. Test deployment: juju deploy ./openclaw_*.charm"
    echo "4. Push to GitHub and set up CharmHub publishing"
    exit 0
else
    echo ""
    echo "❌ Some validations failed. Please fix the issues above."
    exit 1
fi
