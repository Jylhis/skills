"""Tests for run_loop.py split_eval_set."""

import sys
import types

import pytest

# Mock anthropic before importing run_loop (it imports anthropic at module level)
if "anthropic" not in sys.modules:
    mock_anthropic = types.ModuleType("anthropic")
    mock_anthropic.Anthropic = type("Anthropic", (), {})
    sys.modules["anthropic"] = mock_anthropic

from scripts.run_loop import split_eval_set


class TestSplitEvalSet:
    def test_basic_split(self, sample_eval_set):
        train, test = split_eval_set(sample_eval_set, holdout=0.4)
        assert len(train) + len(test) == len(sample_eval_set)

    def test_holdout_proportion(self, sample_eval_set):
        train, test = split_eval_set(sample_eval_set, holdout=0.4)
        # With 4 trigger + 4 no-trigger and 0.4 holdout:
        # test should get ~1-2 from each group (min 1)
        assert len(test) >= 2  # at least 1 from each polarity

    def test_stratified(self, sample_eval_set):
        """Both train and test should have both trigger and no-trigger queries."""
        train, test = split_eval_set(sample_eval_set, holdout=0.4)
        train_triggers = [e for e in train if e["should_trigger"]]
        train_no_triggers = [e for e in train if not e["should_trigger"]]
        test_triggers = [e for e in test if e["should_trigger"]]
        test_no_triggers = [e for e in test if not e["should_trigger"]]
        assert len(train_triggers) > 0
        assert len(train_no_triggers) > 0
        assert len(test_triggers) > 0
        assert len(test_no_triggers) > 0

    def test_deterministic_with_seed(self, sample_eval_set):
        train1, test1 = split_eval_set(sample_eval_set, holdout=0.4, seed=42)
        train2, test2 = split_eval_set(sample_eval_set, holdout=0.4, seed=42)
        assert [e["query"] for e in train1] == [e["query"] for e in train2]
        assert [e["query"] for e in test1] == [e["query"] for e in test2]

    def test_different_seed_different_split(self, sample_eval_set):
        train1, test1 = split_eval_set(sample_eval_set, holdout=0.4, seed=42)
        train2, test2 = split_eval_set(sample_eval_set, holdout=0.4, seed=99)
        # Very unlikely to be identical with different seeds
        queries1 = {e["query"] for e in test1}
        queries2 = {e["query"] for e in test2}
        # They might overlap but shouldn't always be identical
        # This is a probabilistic test — just ensure they produce valid splits
        assert len(train2) + len(test2) == len(sample_eval_set)

    def test_minimum_one_per_group(self):
        """Even with very small groups, at least 1 goes to test."""
        eval_set = [
            {"query": "trigger", "should_trigger": True},
            {"query": "no-trigger", "should_trigger": False},
        ]
        train, test = split_eval_set(eval_set, holdout=0.4)
        # With max(1, int(1*0.4))=max(1,0)=1, each group puts 1 in test
        assert len(test) == 2
        assert len(train) == 0  # all go to test with tiny sets

    def test_all_same_polarity(self):
        """Works when all queries have the same polarity."""
        eval_set = [
            {"query": f"q{i}", "should_trigger": True}
            for i in range(5)
        ]
        # The no_trigger list is empty, so max(1, int(0*0.4))=1
        # This will try to take 1 from empty list → test gets less
        train, test = split_eval_set(eval_set, holdout=0.4)
        assert len(train) + len(test) == len(eval_set)

    def test_no_query_lost(self, sample_eval_set):
        """All original queries must appear in exactly one split."""
        train, test = split_eval_set(sample_eval_set, holdout=0.4)
        all_queries = {e["query"] for e in train} | {e["query"] for e in test}
        original_queries = {e["query"] for e in sample_eval_set}
        assert all_queries == original_queries
