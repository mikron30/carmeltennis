"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");

const {resolvePlayerEmails} = require("../src/video/users");

const firstName = "\u05e9\u05dd \u05e4\u05e8\u05d8\u05d9";
const lastName = "\u05e9\u05dd \u05de\u05e9\u05e4\u05d7\u05d4";
const email = "\u05de\u05d9\u05d9\u05dc";

function user(first, last, address) {
  return {
    data: () => ({[firstName]: first, [lastName]: last, [email]: address}),
  };
}

test("user lookup normalizes a full Hebrew name and returns both player emails", () => {
  const recipients = resolvePlayerEmails([
    user("\u05d0\u05d5\u05d3\u05d9", "\u05d0\u05e9", "ODI@example.com"),
    user("\u05e8\u05e0\u05d9", "\u05dc\u05e4\u05dc\u05e8", "rani@example.com"),
  ], ["  \u05d0\u05d5\u05d3\u05d9   \u05d0\u05e9", "\u05e8\u05e0\u05d9 \u05dc\u05e4\u05dc\u05e8"]);

  assert.deepEqual(recipients, ["odi@example.com", "rani@example.com"]);
});

test("user lookup accepts duplicated imports only when their email agrees", () => {
  const recipients = resolvePlayerEmails([
    user("Test", "Player", "one@example.com"),
    user("Test", "Player", "ONE@example.com"),
    user("Second", "Player", "second@example.com"),
  ], ["Test Player", "Second Player"]);

  assert.deepEqual(recipients, ["one@example.com", "second@example.com"]);
});

test("user lookup rejects a player name mapped to more than one email", () => {
  assert.throws(
      () => resolvePlayerEmails([
        user("Test", "Player", "one@example.com"),
        user("Test", "Player", "two@example.com"),
        user("Second", "Player", "second@example.com"),
      ], ["Test Player", "Second Player"]),
      (error) => error.code === "player_ambiguous",
  );
});

test("manager placeholder players are never resolved to recipients", () => {
  assert.throws(
      () => resolvePlayerEmails([], ["!manager booking", "Other Player"]),
      (error) => error.code === "player_not_resolvable",
  );
});
