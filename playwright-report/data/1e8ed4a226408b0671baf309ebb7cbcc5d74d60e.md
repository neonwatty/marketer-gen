# Page snapshot

```yaml
- main [ref=e2]:
  - generic [ref=e3]:
    - heading "Sign Up" [level=1] [ref=e4]
    - generic [ref=e5]:
      - generic [ref=e6]:
        - heading "1 error prohibited this user from being saved:" [level=2] [ref=e7]
        - list [ref=e8]:
          - listitem [ref=e9]: Password can't be blank
      - generic [ref=e10]:
        - generic [ref=e11]: Email address
        - textbox "Email address" [ref=e12]
      - generic [ref=e13]:
        - generic [ref=e15]: Password
        - textbox "Password" [ref=e17]
      - generic [ref=e18]:
        - generic [ref=e19]: Password confirmation
        - textbox "Password confirmation" [ref=e20]
      - generic [ref=e21]:
        - button "Sign Up" [ref=e22] [cursor=pointer]
        - link "Sign In" [ref=e23] [cursor=pointer]:
          - /url: /session/new
```