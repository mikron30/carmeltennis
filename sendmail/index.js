"use strict";

const cors = require("cors");
const express = require("express");
const nodemailer = require("nodemailer");

function requiredEnvironment(name) {
  const value = String(process.env[name] || "").trim();
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

function optionalEnvironment(name, fallback) {
  const value = String(process.env[name] || "").trim();
  return value || fallback;
}

function smtpPort() {
  const value = Number(optionalEnvironment("SMTP_PORT", "465"));
  if (!Number.isInteger(value) || value < 1 || value > 65535) {
    throw new Error("SMTP_PORT must be a valid TCP port number");
  }
  return value;
}

function smtpSecure() {
  const value = optionalEnvironment("SMTP_SECURE", "true").toLowerCase();
  if (value === "true") return true;
  if (value === "false") return false;
  throw new Error("SMTP_SECURE must be true or false");
}

const smtpUser = requiredEnvironment("SMTP_USER");
const transporter = nodemailer.createTransport({
  host: optionalEnvironment("SMTP_HOST", "smtp.gmail.com"),
  port: smtpPort(),
  secure: smtpSecure(),
  auth: {
    user: smtpUser,
    // Bound from Google Secret Manager in Cloud Run. Never put this in source,
    // a committed .env file, Flutter, Firebase Functions, or an ESP32.
    pass: requiredEnvironment("SMTP_PASSWORD"),
  },
});

const sender = optionalEnvironment(
    "SMTP_FROM",
    `"מועדון טניס כרמל" <${smtpUser}>`,
);
const app = express();
app.disable("x-powered-by");
// Preserve the existing web app's direct mail calls. Do not make this service
// private until the existing caller is migrated to an authenticated path.
app.use(cors());
app.use(express.json({limit: "64kb"}));

app.get("/healthz", (_request, response) => {
  response.status(200).json({ok: true});
});

app.post("/sendMail", async (request, response) => {
  const {to, subject, html} = request.body || {};
  if (typeof to !== "string" || !to.trim() ||
      typeof subject !== "string" || !subject.trim() ||
      typeof html !== "string" || !html.trim()) {
    response.status(400).json({error: "to, subject, and html are required"});
    return;
  }

  // Deliberately log no email address, HTML, password, or full request body.
  console.info("Mail request accepted", {
    hasIdempotencyKey: Boolean(request.get("X-Idempotency-Key")),
  });

  try {
    await transporter.sendMail({
      from: sender,
      to: to.trim(),
      subject: subject.trim(),
      html,
    });
    response.status(200).send("Email sent!");
  } catch (error) {
    console.error("Mail delivery failed", {
      name: error?.name,
      code: error?.code,
    });
    response.status(500).send("Failed to send email");
  }
});

const port = Number(process.env.PORT) || 8080;
app.listen(port, () => console.info("Email service listening", {port}));
