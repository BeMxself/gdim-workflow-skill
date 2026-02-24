#!/usr/bin/env bash
# Quality gates for GDIM automation
# Usage: source automation/ai-coding/lib/validate.sh
#
# After run_quality_gates, check:
#   VALIDATE_RESULT  — human-readable report
#   GATE_FAILURES    — failure count
#   FAILURE_TYPE     — "compile_failed"|"test_failed"|"malformed_output"|"path_violation"|""

# Maven gate timeout (seconds). Override via MVN_GATE_TIMEOUT env var.
MVN_GATE_TIMEOUT="${MVN_GATE_TIMEOUT:-600}"

# Match GDIM phase file with both naming conventions:
#   Convention A (spec): {phase}.round{N}.md  e.g. 00-scope-definition.round1.md
#   Convention B (legacy): *round{N}*{phase}*  e.g. R1-00-scope.md
# Returns 0 if at least one match found.
_match_gdim_phase_file() {
    local dir="$1" round="$2" phase="$3"
    # shellcheck disable=SC2086
    ls ${dir}/*${phase}*round${round}* 1>/dev/null 2>&1 && return 0
    ls ${dir}/*${phase}*.round${round}.* 1>/dev/null 2>&1 && return 0
    ls ${dir}/*round${round}*${phase}* 1>/dev/null 2>&1 && return 0
    return 1
}

# Find a GDIM phase file and return its path (first match).
_find_gdim_phase_file() {
    local dir="$1" round="$2" phase="$3"
    local f
    f=$(find "$dir" \( -name "*${phase}*round${round}*" -o -name "*${phase}*.round${round}.*" -o -name "*round${round}*${phase}*" \) -type f 2>/dev/null | head -1)
    echo "$f"
}

# Run all quality gates for a round.
# Returns 0 if all pass, 1 if any fail.
# Sets VALIDATE_RESULT, GATE_FAILURES, FAILURE_TYPE, COMPILE_ERROR_LOG.
run_quality_gates() {
    local flow_slug="$1"
    local round="$2"
    local modules="$3"       # comma-separated module paths
    local workflow_dir="$4"
    local allowed_paths="$5" # comma-separated allowed path prefixes (optional)
    local baseline_commit="$6" # commit hash at round start (optional, for path whitelist)

    GATE_FAILURES=0
    FAILURE_TYPE=""
    COMPILE_ERROR_LOG=""
    TEST_ERROR_LOG=""
    VALIDATE_RESULT=""

    # Gate 1: Maven compile (with timeout)
    if [ -n "$modules" ]; then
        local pl_arg
        pl_arg=$(echo "$modules" | tr ',' ',')
        log_info "Gate: mvn compile -pl ${pl_arg} -am (timeout=${MVN_GATE_TIMEOUT}s)"
        local compile_output
        local compile_exit=0
        compile_output=$(timeout "$MVN_GATE_TIMEOUT" mvn compile -pl "$pl_arg" -am 2>&1) || compile_exit=$?
        if [ "$compile_exit" -eq 0 ]; then
            VALIDATE_RESULT+="[PASS] mvn compile\n"
        elif [ "$compile_exit" -eq 124 ]; then
            VALIDATE_RESULT+="[FAIL] mvn compile (timeout after ${MVN_GATE_TIMEOUT}s)\n"
            COMPILE_ERROR_LOG="$compile_output"
            FAILURE_TYPE="compile_failed"
            GATE_FAILURES=$((GATE_FAILURES + 1))
        else
            VALIDATE_RESULT+="[FAIL] mvn compile (exit=${compile_exit})\n"
            COMPILE_ERROR_LOG="$compile_output"
            FAILURE_TYPE="compile_failed"
            GATE_FAILURES=$((GATE_FAILURES + 1))
        fi
    else
        VALIDATE_RESULT+="[SKIP] mvn compile (no modules specified)\n"
    fi

    # Gate 2: Maven test (with timeout)
    if [ -n "$modules" ]; then
        local pl_arg_test
        pl_arg_test=$(echo "$modules" | tr ',' ',')
        log_info "Gate: mvn test -pl ${pl_arg_test} -am (timeout=${MVN_GATE_TIMEOUT}s)"
        local test_output
        local test_exit=0
        test_output=$(timeout "$MVN_GATE_TIMEOUT" mvn test -pl "$pl_arg_test" -am 2>&1) || test_exit=$?
        if [ "$test_exit" -eq 0 ]; then
            VALIDATE_RESULT+="[PASS] mvn test\n"
        elif [ "$test_exit" -eq 124 ]; then
            VALIDATE_RESULT+="[FAIL] mvn test (timeout after ${MVN_GATE_TIMEOUT}s)\n"
            TEST_ERROR_LOG="$test_output"
            if [ -z "$FAILURE_TYPE" ]; then
                FAILURE_TYPE="test_failed"
            fi
            GATE_FAILURES=$((GATE_FAILURES + 1))
        else
            VALIDATE_RESULT+="[FAIL] mvn test (exit=${test_exit})\n"
            TEST_ERROR_LOG="$test_output"
            if [ -z "$FAILURE_TYPE" ]; then
                FAILURE_TYPE="test_failed"
            fi
            GATE_FAILURES=$((GATE_FAILURES + 1))
        fi
    else
        VALIDATE_RESULT+="[SKIP] mvn test (no modules specified)\n"
    fi

    # Gate 3: Path whitelist (if allowed_paths provided)
    if [ -n "$allowed_paths" ]; then
        # Collect all changes since round baseline: committed + staged + unstaged + untracked
        local changed_files=""
        if [ -n "$baseline_commit" ]; then
            local committed
            committed=$(git diff --name-only "$baseline_commit" HEAD 2>/dev/null || echo "")
            local staged
            staged=$(git diff --name-only --cached 2>/dev/null || echo "")
            local unstaged
            unstaged=$(git diff --name-only 2>/dev/null || echo "")
            local untracked
            untracked=$(git ls-files --others --exclude-standard 2>/dev/null || echo "")
            changed_files=$(printf '%s\n%s\n%s\n%s' "$committed" "$staged" "$unstaged" "$untracked" | sort -u | grep -v '^$' || true)
        else
            local from_head
            from_head=$(git diff --name-only HEAD~1 HEAD 2>/dev/null || echo "")
            local wt
            wt=$(git diff --name-only 2>/dev/null || echo "")
            local st
            st=$(git diff --name-only --cached 2>/dev/null || echo "")
            local untracked
            untracked=$(git ls-files --others --exclude-standard 2>/dev/null || echo "")
            changed_files=$(printf '%s\n%s\n%s\n%s' "$from_head" "$wt" "$st" "$untracked" | sort -u | grep -v '^$' || true)
        fi

        if [ -n "$changed_files" ]; then
            local violations=""
            while IFS= read -r file; do
                [ -z "$file" ] && continue
                local allowed=0
                IFS=',' read -ra paths <<< "$allowed_paths"
                for prefix in "${paths[@]}"; do
                    prefix=$(echo "$prefix" | xargs)  # trim whitespace
                    if [[ "$file" == ${prefix}* ]]; then
                        allowed=1
                        break
                    fi
                done
                if [ "$allowed" -eq 0 ]; then
                    violations+="  $file\n"
                fi
            done <<< "$changed_files"
            if [ -n "$violations" ]; then
                VALIDATE_RESULT+="[FAIL] path whitelist — out-of-bounds changes:\n${violations}"
                if [ -z "$FAILURE_TYPE" ]; then
                    FAILURE_TYPE="path_violation"
                fi
                GATE_FAILURES=$((GATE_FAILURES + 1))
            else
                VALIDATE_RESULT+="[PASS] path whitelist\n"
            fi
        else
            VALIDATE_RESULT+="[SKIP] path whitelist (no new changed files)\n"
        fi
    fi

    # Gate 4: GDIM files exist (scope, design, plan, summary, gap-analysis)
    local expected_files=("scope" "design" "plan" "summary" "gap-analysis")
    local missing_docs=0
    for phase in "${expected_files[@]}"; do
        if _match_gdim_phase_file "$workflow_dir" "$round" "$phase"; then
            VALIDATE_RESULT+="[PASS] ${phase} file exists\n"
        else
            VALIDATE_RESULT+="[MISS] ${phase} file not found (dir: ${workflow_dir}, round: ${round})\n"
            missing_docs=$((missing_docs + 1))
        fi
    done
    if [ "$missing_docs" -gt 0 ]; then
        GATE_FAILURES=$((GATE_FAILURES + missing_docs))
        if [ -z "$FAILURE_TYPE" ]; then
            FAILURE_TYPE="malformed_output"
        fi
    fi

    # Gate 4b: Gap file parseable
    local gap_file
    gap_file=$(_find_gdim_phase_file "$workflow_dir" "$round" "gap-analysis")
    if [ -n "$gap_file" ]; then
        if grep -qiE 'BLOCKED|未关闭|已关闭|Identified Gaps|No.*gap|Gap Closure' "$gap_file" 2>/dev/null; then
            VALIDATE_RESULT+="[PASS] gap file parseable\n"
        else
            VALIDATE_RESULT+="[WARN] gap file lacks expected keywords\n"
        fi
    else
        VALIDATE_RESULT+="[MISS] gap file not found for parsing\n"
    fi

    # Gate 5: Git commit exists for this round
    local commit_marker="${flow_slug}.*R${round}\|R${round}.*${flow_slug}\|round.*${round}"
    if git log --oneline -5 2>/dev/null | grep -qiE "$commit_marker"; then
        VALIDATE_RESULT+="[PASS] git commit found\n"
    else
        VALIDATE_RESULT+="[WARN] no git commit matching R${round} for ${flow_slug}\n"
    fi

    return $GATE_FAILURES
}

# Check if gap analysis indicates all gaps are closed.
# IMPORTANT: defaults to "open" (return 1) when content is unrecognized,
# to avoid false-positive closure on malformed or empty gap files.
no_open_gaps() {
    local gap_file="$1"
    if [ ! -f "$gap_file" ]; then
        return 1
    fi
    # Must positively match a "closed" pattern to return 0
    if grep -qiE 'no.*open.*gap|all.*gap.*closed|无未关闭|所有.*gap.*已关闭|gap.*closure.*complete' "$gap_file" 2>/dev/null; then
        # Double-check: if specific gap IDs are marked open/unresolved, it's not closed
        # Use specific patterns that won't match "no open gaps" or "all gaps closed"
        if grep -qiE 'G[1-6]-[0-9]+.*(未关闭|unresolved|open|pending)' "$gap_file" 2>/dev/null; then
            return 1
        fi
        return 0
    fi
    # No positive closure signal found — treat as open
    return 1
}

# Check if gap analysis contains BLOCKED flag
has_blocked_flag() {
    local gap_file="$1"
    if [ ! -f "$gap_file" ]; then
        return 1
    fi
    grep -qiE 'BLOCKED' "$gap_file" 2>/dev/null
}

# Check if new commits exist since last round
no_new_commits_since_last_round() {
    local last_commit_count
    last_commit_count="${LAST_COMMIT_COUNT:-0}"
    local current_count
    current_count=$(git rev-list --count HEAD 2>/dev/null || echo "0")
    if [ "$current_count" -le "$last_commit_count" ]; then
        return 0
    fi
    return 1
}
