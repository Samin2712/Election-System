import * as jwt from "jsonwebtoken";
import type { Secret, SignOptions } from "jsonwebtoken";

function requireEnv(name: string): string {
  const v = process.env[name];
  if (!v) throw new Error(`${name} must be set in .env`);
  return v;
}

const JWT_SECRET: Secret = requireEnv("JWT_SECRET");
const JWT_REFRESH_SECRET: Secret = requireEnv("JWT_REFRESH_SECRET");

// IMPORTANT: type expiresIn correctly so TS picks the right overload
const JWT_ACCESS_EXPIRES_IN: SignOptions["expiresIn"] =
  (process.env.JWT_ACCESS_EXPIRES_IN as SignOptions["expiresIn"]) ?? "15m";

const JWT_REFRESH_EXPIRES_IN: SignOptions["expiresIn"] =
  (process.env.JWT_REFRESH_EXPIRES_IN as SignOptions["expiresIn"]) ?? "7d";

export interface TokenPayload {
  user_id: number;
  role_id: number;
  org_id?: number;
}

export interface VerifiedToken extends TokenPayload {
  iat: number;
  exp: number;
}

export function signAccessToken(payload: TokenPayload): string {
  const options: SignOptions = { expiresIn: JWT_ACCESS_EXPIRES_IN };
  return jwt.sign(payload, JWT_SECRET, options);
}

export function signRefreshToken(payload: TokenPayload): string {
  const options: SignOptions = { expiresIn: JWT_REFRESH_EXPIRES_IN };
  return jwt.sign(payload, JWT_REFRESH_SECRET, options);
}

export function verifyAccessToken(token: string): VerifiedToken {
  try {
    return jwt.verify(token, JWT_SECRET) as VerifiedToken;
  } catch {
    throw new Error("Invalid or expired access token");
  }
}

export function verifyRefreshToken(token: string): VerifiedToken {
  try {
    return jwt.verify(token, JWT_REFRESH_SECRET) as VerifiedToken;
  } catch {
    throw new Error("Invalid or expired refresh token");
  }
}
