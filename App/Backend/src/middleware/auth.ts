import { Request, Response, NextFunction } from "express";
import { verifyAccessToken, VerifiedToken } from "../utils/jwt";

declare global {
  namespace Express {
    interface Request {
      user?: VerifiedToken;
    }
  }
}

/**
 * Middleware to verify JWT token
 * Extracts user_id, role_id from token and attaches to req.user
 */
export function authMiddleware(req: Request, res: Response, next: NextFunction) {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return res.status(401).json({ ok: false, error: "Missing or invalid authorization header" });
    }

    const token = authHeader.substring(7); // Remove "Bearer "
    const user = verifyAccessToken(token);
    
    req.user = user;
    next();
  } catch (err: any) {
    return res.status(401).json({ ok: false, error: err.message || "Unauthorized" });
  }
}

/**
 * Optional auth middleware - doesn't fail if no token
 * Useful for routes that can be accessed by both authenticated and unauthenticated users
 */
export function optionalAuthMiddleware(req: Request, res: Response, next: NextFunction) {
  try {
    const authHeader = req.headers.authorization;
    if (authHeader && authHeader.startsWith("Bearer ")) {
      const token = authHeader.substring(7);
      const user = verifyAccessToken(token);
      req.user = user;
    }
    next();
  } catch (err) {
    // Silently fail - user is optional
    next();
  }
}
