import { NextAuthOptions } from "next-auth";
import CredentialsProvider from "next-auth/providers/credentials";
import GitHubProvider from "next-auth/providers/github";
import GoogleProvider from "next-auth/providers/google";

import { PrismaAdapter } from "@auth/prisma-adapter";

import { prisma } from "./database";

export const authOptions: NextAuthOptions = {
  adapter: PrismaAdapter(prisma) as any,
  providers: [
    // Development-only demo authentication
    ...(process.env.NODE_ENV === "development"
      ? [
          CredentialsProvider({
            id: "demo",
            name: "Demo User",
            credentials: {
              email: { label: "Email", type: "email", placeholder: "demo@example.com" },
            },
            async authorize(credentials) {
              // Development-only demo user
              if (credentials?.email === "demo@example.com") {
                return {
                  id: "demo-user-id",
                  email: "demo@example.com",
                  name: "Demo User",
                  image: null,
                  role: "USER",
                };
              }
              return null;
            },
          }),
        ]
      : []),
    // Providers are configured but disabled by default
    // These can be enabled by setting the appropriate environment variables
    ...(process.env.GOOGLE_CLIENT_ID && process.env.GOOGLE_CLIENT_SECRET
      ? [
          GoogleProvider({
            clientId: process.env.GOOGLE_CLIENT_ID,
            clientSecret: process.env.GOOGLE_CLIENT_SECRET,
          }),
        ]
      : []),
    ...(process.env.GITHUB_CLIENT_ID && process.env.GITHUB_CLIENT_SECRET
      ? [
          GitHubProvider({
            clientId: process.env.GITHUB_CLIENT_ID,
            clientSecret: process.env.GITHUB_CLIENT_SECRET,
          }),
        ]
      : []),
  ],
  session: {
    strategy: "jwt",
  },
  pages: {
    signIn: "/auth/signin",
  },
  callbacks: {
    async session({ session, token, user }) {
      // Handle case where session.user is undefined
      if (!session?.user) {
        return session;
      }

      // Handle both JWT strategy (token) and database strategy (user)
      const userId = user?.id || token?.sub;
      if (userId) {
        (session.user as any).id = userId;
        // Add custom user fields to session if needed
        try {
          const dbUser = await prisma.user.findUnique({
            where: { id: userId },
            select: { role: true },
          });
          if (dbUser) {
            (session.user as any).role = dbUser.role;
          }
        } catch (error) {
          // Log error but don't fail the session
          console.error('Error fetching user role:', error);
        }
      }
      return session;
    },
    async jwt({ user, token }) {
      if (user) {
        (token as any).role = (user as any).role;
      }
      return token;
    },
  },
  events: {
    async createUser({ user }) {
      // Log user creation for analytics
      console.log(`New user created: ${user.email}`);
    },
  },
  // Disable authentication by default - can be enabled later
  debug: process.env.NODE_ENV === "development",
};