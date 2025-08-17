import { NextAuthOptions } from "next-auth";
import GitHubProvider from "next-auth/providers/github";
import GoogleProvider from "next-auth/providers/google";

import { PrismaAdapter } from "@auth/prisma-adapter";

import { prisma } from "./db";

export const authOptions: NextAuthOptions = {
  adapter: PrismaAdapter(prisma) as any,
  providers: [
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
    strategy: "database",
  },
  pages: {
    signIn: "/auth/signin",
  },
  callbacks: {
    async session({ session, user }) {
      if (session?.user && user) {
        (session.user as any).id = user.id;
        // Add custom user fields to session if needed
        try {
          const dbUser = await prisma.user.findUnique({
            where: { id: user.id },
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